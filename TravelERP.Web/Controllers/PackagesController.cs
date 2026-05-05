using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class PackagesController : Controller
{
    private readonly IPackageRepository _repo;
    private readonly ITenantContext _tenant;

    public PackagesController(IPackageRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        ViewData["Title"] = "Tour Packages";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Tour Packages", null) };
        return View(await _repo.GetAllAsync());
    }

    public async Task<IActionResult> Details(int id)
    {
        var pkg = await _repo.GetByIdAsync(id);
        if (pkg == null) return NotFound();
        ViewData["Title"] = pkg.Name;
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Tour Packages", "/Packages"), (pkg.Name, null) };
        return View(pkg);
    }

    public async Task<IActionResult> Create()
    {
        ViewData["Title"] = "New Package";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Tour Packages", "/Packages"), ("New Package", null) };
        return View(new TourPackage { PackageCode = await _repo.GeneratePackageCodeAsync() });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(TourPackage model)
    {
        if (!ModelState.IsValid) return View(model);
        model.CreatedBy = _tenant.UserId;
        model.CreatedAt = DateTime.UtcNow;
        await _repo.InsertAsync(model);
        TempData["Success"] = $"Package '{model.Name}' created successfully.";
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(int id)
    {
        var pkg = await _repo.GetByIdAsync(id);
        if (pkg == null) return NotFound();
        ViewData["Title"] = $"Edit — {pkg.Name}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Tour Packages", "/Packages"), ("Edit", null) };
        return View(pkg);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(TourPackage model)
    {
        if (!ModelState.IsValid) return View(model);
        model.UpdatedBy = _tenant.UserId;
        model.UpdatedAt = DateTime.UtcNow;
        await _repo.UpdateAsync(model);
        TempData["Success"] = "Package updated successfully.";
        return RedirectToAction(nameof(Details), new { id = model.Id });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Package deleted.";
        return RedirectToAction(nameof(Index));
    }
}
