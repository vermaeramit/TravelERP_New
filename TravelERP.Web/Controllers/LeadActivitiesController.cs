using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class LeadActivitiesController : Controller
{
    private readonly ILeadActivityRepository _repo;
    private readonly ITenantContext _tenant;

    public LeadActivitiesController(ILeadActivityRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Add(int leadId, string activityType, string? subject,
        string? notes, DateTime? activityAt, DateTime? nextFollowUpAt)
    {
        if (!_tenant.CanEdit(AppModules.Leads)) return Forbid();
        if (leadId <= 0 || string.IsNullOrWhiteSpace(activityType))
        {
            TempData["Error"] = "Invalid activity.";
            return RedirectToLead(leadId);
        }

        // If only nextFollowUpAt is set (no notes/subject), treat as a scheduled future activity
        var isScheduled = nextFollowUpAt.HasValue && nextFollowUpAt.Value > DateTime.UtcNow
                          && string.IsNullOrWhiteSpace(notes) && string.IsNullOrWhiteSpace(subject);

        var activity = new LeadActivity
        {
            LeadId         = leadId,
            ActivityType   = activityType,
            Subject        = string.IsNullOrWhiteSpace(subject) ? null : subject.Trim(),
            Notes          = string.IsNullOrWhiteSpace(notes)   ? null : notes.Trim(),
            ActivityAt     = activityAt ?? DateTime.UtcNow,
            NextFollowUpAt = nextFollowUpAt,
            IsCompleted    = activityType != ActivityTypes.FollowUp || !nextFollowUpAt.HasValue
        };

        await _repo.InsertAsync(activity);
        TempData["Success"] = "Activity logged.";
        return RedirectToLead(leadId);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(int id, int leadId, string activityType,
        string? subject, string? notes, DateTime? activityAt, DateTime? nextFollowUpAt, bool isCompleted = true)
    {
        if (!_tenant.CanEdit(AppModules.Leads)) return Forbid();
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return NotFound();

        existing.ActivityType   = activityType;
        existing.Subject        = string.IsNullOrWhiteSpace(subject) ? null : subject.Trim();
        existing.Notes          = string.IsNullOrWhiteSpace(notes)   ? null : notes.Trim();
        existing.ActivityAt     = activityAt ?? existing.ActivityAt;
        existing.NextFollowUpAt = nextFollowUpAt;
        existing.IsCompleted    = isCompleted;

        await _repo.UpdateAsync(existing);
        TempData["Success"] = "Activity updated.";
        return RedirectToLead(leadId);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Complete(int id, int leadId)
    {
        if (!_tenant.CanEdit(AppModules.Leads)) return Forbid();
        await _repo.CompleteAsync(id);
        TempData["Success"] = "Marked as done.";
        return RedirectToLead(leadId);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id, int leadId)
    {
        if (!_tenant.CanEdit(AppModules.Leads)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Activity removed.";
        return RedirectToLead(leadId);
    }

    private IActionResult RedirectToLead(int leadId) =>
        RedirectToAction("Details", "Leads", new { id = leadId });
}
