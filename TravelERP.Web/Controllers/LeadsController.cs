using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class LeadsController : Controller
{
    private readonly ILeadRepository _repo;
    private readonly ILeadStatusRepository _statuses;
    private readonly ILeadSourceRepository _sources;
    private readonly IDestinationRepository _destinations;
    private readonly IUserRepository _users;
    private readonly ITenantContext _tenant;

    public LeadsController(ILeadRepository repo, ILeadStatusRepository statuses,
        ILeadSourceRepository sources, IDestinationRepository destinations,
        IUserRepository users, ITenantContext tenant)
    {
        _repo = repo;
        _statuses = statuses;
        _sources = sources;
        _destinations = destinations;
        _users = users;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index(int? statusId, int? sourceId, int? assignedTo,
        int? destinationId, DateTime? dateFrom, DateTime? dateTo,
        string? search, bool showClosed = false, bool filtered = false,
        int page = 1, int pageSize = 10)
    {
        if (!_tenant.CanView(AppModules.Leads)) return Forbid();
        ViewData["Title"] = "Leads";

        // "Include closed" defaults ON unless the user explicitly unchecked it via the filter form.
        // Form submissions carry filtered=1; absence of "showClosed" then means unchecked → false.
        var effectiveShowClosed = filtered ? showClosed : true;

        var filter = new LeadFilter
        {
            StatusId      = statusId,
            SourceId      = sourceId,
            AssignedTo    = assignedTo,
            DestinationId = destinationId,
            DateFrom      = dateFrom,
            DateTo        = dateTo,
            Search        = string.IsNullOrWhiteSpace(search) ? null : search.Trim(),
            ShowClosed    = effectiveShowClosed,
            Page          = page < 1 ? 1 : page,
            PageSize      = pageSize is < 5 or > 100 ? 10 : pageSize
        };

        ViewBag.Statuses     = await _statuses.GetAllAsync();
        ViewBag.Sources      = await _sources.GetAllAsync();
        ViewBag.Destinations = await _destinations.GetAllAsync();
        ViewBag.Users        = await _users.GetByCompanyAsync(_tenant.CompanyId);
        ViewBag.Filter       = filter;
        ViewBag.AssignedToUserMap = (await _users.GetByCompanyAsync(_tenant.CompanyId))
            .ToDictionary(u => u.Id, u => u.FullName);

        var paged = await _repo.GetPagedAsync(filter);
        return View(paged);
    }

    [HttpGet]
    public async Task<IActionResult> Create()
    {
        if (!_tenant.CanAdd(AppModules.Leads)) return Forbid();
        ViewData["Title"] = "Add Lead";
        await PopulateLookupsAsync();
        return View(new Lead { AssignedToUserId = _tenant.UserId });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Lead model)
    {
        if (!_tenant.CanAdd(AppModules.Leads)) return Forbid();
        Validate(model);
        if (!ModelState.IsValid)
        {
            ViewData["Title"] = "Add Lead";
            await PopulateLookupsAsync();
            return View(model);
        }

        var (id, leadNumber) = await _repo.InsertAsync(model);
        TempData["Success"] = $"Lead {leadNumber} created.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Details(int id,
        [FromServices] ILeadActivityRepository activities,
        [FromServices] IActivityTemplateRepository templates,
        [FromServices] IPackageRepository packages,
        [FromServices] IBookingRepository bookings)
    {
        if (!_tenant.CanView(AppModules.Leads)) return Forbid();
        var lead = await _repo.GetByIdAsync(id);
        if (lead == null) return NotFound();
        ViewData["Title"] = $"Lead {lead.LeadNumber}";

        // Resolve assigned-to name (cross-DB lookup)
        if (lead.AssignedToUserId.HasValue)
        {
            var user = await _users.GetByIdAsync(lead.AssignedToUserId.Value);
            ViewBag.AssignedToName = user?.FullName;
        }

        // Activities timeline + author-name lookup
        var acts = (await activities.GetByLeadAsync(id)).ToList();
        var authorIds = acts.Select(a => a.CreatedByUserId).Where(uid => uid > 0).Distinct().ToList();
        var authorMap = new Dictionary<int, string>();
        foreach (var uid in authorIds)
        {
            var u = await _users.GetByIdAsync(uid);
            if (u != null) authorMap[uid] = u.FullName;
        }

        ViewBag.Activities = acts;
        ViewBag.AuthorMap  = authorMap;
        ViewBag.Statuses   = await _statuses.GetAllAsync();
        ViewBag.Templates  = await templates.GetAllAsync();
        ViewBag.Packages   = await packages.GetByLeadAsync(id);
        ViewBag.Bookings   = await bookings.GetByLeadAsync(id);
        return View(lead);
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Leads)) return Forbid();
        var lead = await _repo.GetByIdAsync(id);
        if (lead == null) return NotFound();
        ViewData["Title"] = $"Lead {lead.LeadNumber}";
        await PopulateLookupsAsync();
        return View(lead);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Lead model)
    {
        if (!_tenant.CanEdit(AppModules.Leads)) return Forbid();
        var existing = await _repo.GetByIdAsync(model.Id);
        if (existing == null) return NotFound();

        Validate(model);
        if (!ModelState.IsValid)
        {
            ViewData["Title"] = $"Lead {existing.LeadNumber}";
            await PopulateLookupsAsync();
            return View(model);
        }

        await _repo.UpdateAsync(model);
        TempData["Success"] = "Lead updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangeStatus(int id, int statusId, string? returnUrl)
    {
        if (!_tenant.CanEdit(AppModules.Leads)) return Forbid();
        await _repo.ChangeStatusAsync(id, statusId);
        TempData["Success"] = "Status updated.";
        if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
            return Redirect(returnUrl);
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Leads)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Lead deactivated.";
        return RedirectToAction(nameof(Index));
    }

    private void Validate(Lead m)
    {
        if (string.IsNullOrWhiteSpace(m.Name))
            ModelState.AddModelError(nameof(m.Name), "Name is required.");
        if (m.Adults < 0 || m.Children < 0 || m.Infants < 0)
            ModelState.AddModelError(nameof(m.Adults), "Pax counts cannot be negative.");
    }

    private async Task PopulateLookupsAsync()
    {
        ViewBag.Statuses     = await _statuses.GetAllAsync();
        ViewBag.Sources      = await _sources.GetAllAsync();
        ViewBag.Destinations = await _destinations.GetAllAsync();
        ViewBag.Users        = await _users.GetByCompanyAsync(_tenant.CompanyId);
    }
}
