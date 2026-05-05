using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class SuppliersController : Controller
{
    private readonly ISupplierRepository _repo;
    private readonly ITenantContext _tenant;

    public SuppliersController(ISupplierRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        ViewData["Title"] = "Suppliers";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Suppliers", null) };
        return View(await _repo.GetAllAsync());
    }

    public async Task<IActionResult> Create()
    {
        ViewData["Title"] = "New Supplier";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Suppliers", "/Suppliers"), ("New Supplier", null) };
        return View(new Supplier { SupplierCode = await _repo.GenerateSupplierCodeAsync() });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Supplier model)
    {
        if (!ModelState.IsValid) return View(model);
        model.CreatedBy = _tenant.UserId;
        model.CreatedAt = DateTime.UtcNow;
        await _repo.InsertAsync(model);
        TempData["Success"] = $"Supplier '{model.Name}' added.";
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(int id)
    {
        var supplier = await _repo.GetByIdAsync(id);
        if (supplier == null) return NotFound();
        ViewData["Title"] = $"Edit — {supplier.Name}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Suppliers", "/Suppliers"), ("Edit", null) };
        return View(supplier);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Supplier model)
    {
        if (!ModelState.IsValid) return View(model);
        model.UpdatedBy = _tenant.UserId;
        model.UpdatedAt = DateTime.UtcNow;
        await _repo.UpdateAsync(model);
        TempData["Success"] = "Supplier updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Supplier deleted.";
        return RedirectToAction(nameof(Index));
    }
}
