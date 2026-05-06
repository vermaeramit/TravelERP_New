using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class LeadSourcesController : Controller
{
    private readonly ILeadSourceRepository _repo;
    private readonly ITenantContext _tenant;

    public LeadSourcesController(ILeadSourceRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Lead Sources";
        return View(await _repo.GetAllAsync());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(string name)
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        if (string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Lead source name is required.";
            return RedirectToAction(nameof(Index));
        }
        await _repo.InsertAsync(new LeadSource { Name = name.Trim() });
        TempData["Success"] = $"Lead source '{name.Trim()}' added.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(int id, string name)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        if (string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Lead source name is required.";
            return RedirectToAction(nameof(Index));
        }
        await _repo.UpdateAsync(new LeadSource { Id = id, Name = name.Trim() });
        TempData["Success"] = "Lead source updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Masters)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Lead source deactivated.";
        return RedirectToAction(nameof(Index));
    }
}
