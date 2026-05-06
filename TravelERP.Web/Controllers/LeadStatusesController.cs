using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class LeadStatusesController : Controller
{
    private readonly ILeadStatusRepository _repo;
    private readonly ITenantContext _tenant;

    public static readonly string[] Colors =
        ["primary", "success", "warning", "danger", "info", "secondary", "dark"];

    public LeadStatusesController(ILeadStatusRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Lead Statuses";
        ViewBag.Colors = Colors;
        return View(await _repo.GetAllAsync());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(string name, string color, int displayOrder,
        bool isDefault = false, bool isClosed = false)
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        if (string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Status name is required.";
            return RedirectToAction(nameof(Index));
        }
        await _repo.InsertAsync(new LeadStatus
        {
            Name = name.Trim(),
            Color = Colors.Contains(color) ? color : "secondary",
            DisplayOrder = displayOrder,
            IsDefault = isDefault,
            IsClosed = isClosed
        });
        TempData["Success"] = $"Status '{name.Trim()}' added.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(int id, string name, string color, int displayOrder,
        bool isDefault = false, bool isClosed = false)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        if (string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Status name is required.";
            return RedirectToAction(nameof(Index));
        }
        await _repo.UpdateAsync(new LeadStatus
        {
            Id = id,
            Name = name.Trim(),
            Color = Colors.Contains(color) ? color : "secondary",
            DisplayOrder = displayOrder,
            IsDefault = isDefault,
            IsClosed = isClosed
        });
        TempData["Success"] = "Status updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Masters)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Status deactivated.";
        return RedirectToAction(nameof(Index));
    }
}
