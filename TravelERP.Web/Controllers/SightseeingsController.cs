using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class SightseeingsController : Controller
{
    private readonly ISightseeingRepository _repo;
    private readonly IDestinationRepository _destinations;
    private readonly ITenantContext _tenant;
    private readonly IWebHostEnvironment _env;

    private static readonly string[] AllowedExt = [".jpg", ".jpeg", ".png", ".webp", ".gif"];
    private const long MaxImageBytes = 5 * 1024 * 1024;

    public SightseeingsController(ISightseeingRepository repo, IDestinationRepository destinations,
        ITenantContext tenant, IWebHostEnvironment env)
    {
        _repo = repo;
        _destinations = destinations;
        _tenant = tenant;
        _env = env;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Sightseeings)) return Forbid();
        ViewData["Title"] = "Sightseeing";
        return View(await _repo.GetAllAsync());
    }

    [HttpGet]
    public async Task<IActionResult> Create()
    {
        if (!_tenant.CanAdd(AppModules.Sightseeings)) return Forbid();
        ViewData["Title"] = "Add Sightseeing";
        ViewBag.Destinations = await _destinations.GetAllAsync();
        return View(new Sightseeing());
    }

    [HttpPost, ValidateAntiForgeryToken]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> Create(Sightseeing model, IFormFile? heroImage)
    {
        if (!_tenant.CanAdd(AppModules.Sightseeings)) return Forbid();
        if (model.DestinationId == 0)
            ModelState.AddModelError(nameof(model.DestinationId), "Destination is required.");
        if (string.IsNullOrWhiteSpace(model.Name))
            ModelState.AddModelError(nameof(model.Name), "Sightseeing name is required.");

        if (!ModelState.IsValid)
        {
            ViewData["Title"] = "Add Sightseeing";
            ViewBag.Destinations = await _destinations.GetAllAsync();
            return View(model);
        }

        model.ImageUrl = await SaveImageAsync(heroImage);
        await _repo.InsertAsync(model);

        TempData["Success"] = $"Sightseeing '{model.Name}' created.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Sightseeings)) return Forbid();
        var s = await _repo.GetByIdAsync(id);
        if (s == null) return NotFound();
        ViewData["Title"] = $"Edit — {s.Name}";
        ViewBag.Destinations = await _destinations.GetAllAsync();
        return View(s);
    }

    [HttpPost, ValidateAntiForgeryToken]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> Edit(Sightseeing model, IFormFile? heroImage)
    {
        if (!_tenant.CanEdit(AppModules.Sightseeings)) return Forbid();
        var existing = await _repo.GetByIdAsync(model.Id);
        if (existing == null) return NotFound();

        if (model.DestinationId == 0)
            ModelState.AddModelError(nameof(model.DestinationId), "Destination is required.");
        if (string.IsNullOrWhiteSpace(model.Name))
            ModelState.AddModelError(nameof(model.Name), "Sightseeing name is required.");

        if (!ModelState.IsValid)
        {
            ViewData["Title"] = $"Edit — {existing.Name}";
            ViewBag.Destinations = await _destinations.GetAllAsync();
            model.ImageUrl = existing.ImageUrl;
            return View(model);
        }

        var newImage = await SaveImageAsync(heroImage);
        model.ImageUrl = newImage ?? existing.ImageUrl;
        await _repo.UpdateAsync(model);

        TempData["Success"] = "Sightseeing updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Sightseeings)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Sightseeing deactivated.";
        return RedirectToAction(nameof(Index));
    }

    private async Task<string?> SaveImageAsync(IFormFile? file)
    {
        if (file == null || file.Length == 0) return null;
        if (file.Length > MaxImageBytes) return null;
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExt.Contains(ext)) return null;

        var folder = Path.Combine(_env.WebRootPath, "uploads", "sightseeings");
        Directory.CreateDirectory(folder);
        var fileName = $"{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(folder, fileName);
        await using var fs = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(fs);
        return $"/uploads/sightseeings/{fileName}";
    }
}
