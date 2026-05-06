using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class DestinationsController : Controller
{
    private readonly IDestinationRepository _repo;
    private readonly ITenantContext _tenant;
    private readonly IWebHostEnvironment _env;

    private static readonly string[] AllowedExt = [".jpg", ".jpeg", ".png", ".webp", ".gif"];
    private const long MaxImageBytes = 5 * 1024 * 1024;

    public DestinationsController(IDestinationRepository repo, ITenantContext tenant, IWebHostEnvironment env)
    {
        _repo = repo;
        _tenant = tenant;
        _env = env;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Destinations";
        return View(await _repo.GetAllAsync());
    }

    [HttpGet]
    public IActionResult Create()
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Add Destination";
        return View(new Destination());
    }

    [HttpPost, ValidateAntiForgeryToken]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> Create(Destination model,
        IFormFile? heroImage,
        List<string>? reviewNames,
        List<string>? reviewTexts,
        List<IFormFile?>? reviewImages)
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        if (string.IsNullOrWhiteSpace(model.Name))
            ModelState.AddModelError(nameof(model.Name), "Destination name is required.");

        if (!ModelState.IsValid)
        {
            ViewData["Title"] = "Add Destination";
            return View(model);
        }

        model.ImageUrl = await SaveImageAsync(heroImage);

        var newId = await _repo.InsertAsync(model);
        var reviews = BuildReviews(reviewNames, reviewTexts, reviewImages, existing: null);
        await _repo.ReplaceReviewsAsync(newId, await PersistReviewImagesAsync(reviews));

        TempData["Success"] = $"Destination '{model.Name}' created.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        var dest = await _repo.GetByIdAsync(id);
        if (dest == null) return NotFound();
        ViewData["Title"] = $"Edit — {dest.Name}";
        return View(dest);
    }

    [HttpPost, ValidateAntiForgeryToken]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> Edit(Destination model,
        IFormFile? heroImage,
        List<string>? reviewNames,
        List<string>? reviewTexts,
        List<IFormFile?>? reviewImages,
        List<string>? reviewExistingImages)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        var existing = await _repo.GetByIdAsync(model.Id);
        if (existing == null) return NotFound();

        if (string.IsNullOrWhiteSpace(model.Name))
            ModelState.AddModelError(nameof(model.Name), "Destination name is required.");

        if (!ModelState.IsValid)
        {
            ViewData["Title"] = $"Edit — {existing.Name}";
            model.Reviews = existing.Reviews;
            model.ImageUrl = existing.ImageUrl;
            return View(model);
        }

        var newHero = await SaveImageAsync(heroImage);
        model.ImageUrl = newHero ?? existing.ImageUrl;

        await _repo.UpdateAsync(model);

        var reviews = BuildReviews(reviewNames, reviewTexts, reviewImages, reviewExistingImages);
        await _repo.ReplaceReviewsAsync(model.Id, await PersistReviewImagesAsync(reviews));

        TempData["Success"] = "Destination updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Masters)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Destination deactivated.";
        return RedirectToAction(nameof(Index));
    }

    // ───────────────────────── helpers ─────────────────────────

    private static List<(DestinationReview Review, IFormFile? File)> BuildReviews(
        List<string>? names, List<string>? texts, List<IFormFile?>? files, List<string>? existing)
    {
        var result = new List<(DestinationReview, IFormFile?)>();
        if (names == null) return result;

        for (int i = 0; i < names.Count; i++)
        {
            var nm = names[i];
            if (string.IsNullOrWhiteSpace(nm)) continue;
            var review = new DestinationReview
            {
                TravelerName = nm.Trim(),
                ReviewText   = texts != null && i < texts.Count ? texts[i] : null,
                ImageUrl     = existing != null && i < existing.Count ? existing[i] : null
            };
            var file = files != null && i < files.Count ? files[i] : null;
            result.Add((review, file));
        }
        return result;
    }

    private async Task<List<DestinationReview>> PersistReviewImagesAsync(
        List<(DestinationReview Review, IFormFile? File)> items)
    {
        foreach (var (review, file) in items)
        {
            var saved = await SaveImageAsync(file);
            if (saved != null) review.ImageUrl = saved;
        }
        return items.Select(t => t.Review).ToList();
    }

    private async Task<string?> SaveImageAsync(IFormFile? file)
    {
        if (file == null || file.Length == 0) return null;
        if (file.Length > MaxImageBytes) return null;

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExt.Contains(ext)) return null;

        var folder = Path.Combine(_env.WebRootPath, "uploads", "destinations");
        Directory.CreateDirectory(folder);

        var fileName = $"{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(folder, fileName);

        await using var fs = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(fs);

        return $"/uploads/destinations/{fileName}";
    }
}
