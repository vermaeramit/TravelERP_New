using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class TodayController : Controller
{
    private readonly ILeadActivityRepository _activities;
    private readonly ITenantContext _tenant;

    public TodayController(ILeadActivityRepository activities, ITenantContext tenant)
    {
        _activities = activities;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index(bool myOnly = true)
    {
        if (!_tenant.CanView(AppModules.Leads)) return Forbid();
        ViewData["Title"] = "Today";
        // Restricted-scope users always see only their own follow-ups — toggle is forced on.
        if (_tenant.OnlyAssigned) myOnly = true;
        ViewBag.MyOnly = myOnly;
        ViewBag.MyOnlyForced = _tenant.OnlyAssigned;
        var panel = await _activities.GetTodayPanelAsync(_tenant.UserId, myOnly);
        return View(panel);
    }

    /// <summary>JSON endpoint for the navbar badge — actionable = overdue + today.</summary>
    [HttpGet("Today/Counts")]
    public async Task<IActionResult> Counts(bool myOnly = true)
    {
        if (!_tenant.CanView(AppModules.Leads)) return Forbid();
        if (_tenant.OnlyAssigned) myOnly = true;
        var panel = await _activities.GetTodayPanelAsync(_tenant.UserId, myOnly);
        return Json(new
        {
            overdue   = panel.OverdueCount,
            today     = panel.TodayCount,
            upcoming  = panel.UpcomingCount,
            actionable = panel.ActionableCount
        });
    }

    [HttpPost("Today/MarkDone/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> MarkDone(int id)
    {
        if (!_tenant.CanEdit(AppModules.Leads)) return Forbid();
        await _activities.CompleteAsync(id);
        return Json(new { success = true });
    }
}
