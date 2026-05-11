using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class VisaTypesController : Controller
{
    private readonly IVisaTypeRepository _repo;
    private readonly ITenantContext _tenant;

    public VisaTypesController(IVisaTypeRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.VisaTypes)) return Forbid();
        ViewData["Title"] = "Visa Types";
        return View(await _repo.GetAllAsync());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(string name, string? country)
    {
        if (!_tenant.CanAdd(AppModules.VisaTypes)) return Forbid();
        if (string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Visa type name is required.";
            return RedirectToAction(nameof(Index));
        }
        await _repo.InsertAsync(new VisaType { Name = name.Trim(), Country = country?.Trim() });
        TempData["Success"] = $"Visa type '{name.Trim()}' added.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(int id, string name, string? country)
    {
        if (!_tenant.CanEdit(AppModules.VisaTypes)) return Forbid();
        if (string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Visa type name is required.";
            return RedirectToAction(nameof(Index));
        }
        await _repo.UpdateAsync(new VisaType { Id = id, Name = name.Trim(), Country = country?.Trim() });
        TempData["Success"] = "Visa type updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.VisaTypes)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Visa type deactivated.";
        return RedirectToAction(nameof(Index));
    }
}
