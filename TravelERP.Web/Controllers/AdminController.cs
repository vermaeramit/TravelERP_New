using System.Data;
using System.Security.Claims;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;
using TravelERP.Shared.Enums;

namespace TravelERP.Web.Controllers;

/// <summary>
/// Platform Admin portal. Manages tenants (Companies), Subscription Plans and platform stats.
/// Gated by Role="SuperAdmin" — only the platform admin (MasterUsers.Role=SuperAdmin) reaches it.
/// </summary>
[Authorize(Roles = "SuperAdmin")]
[Route("[controller]")]
public class AdminController : Controller
{
    private readonly ICompanyRepository _companies;
    private readonly ISubscriptionPlanRepository _plans;
    private readonly DbConnectionFactory _factory;

    public AdminController(ICompanyRepository companies, ISubscriptionPlanRepository plans, DbConnectionFactory factory)
    {
        _companies = companies;
        _plans = plans;
        _factory = factory;
    }

    private int CurrentUserId =>
        int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : 0;

    // ─────────────────────── Stats / Home ───────────────────────
    [HttpGet("")]
    [HttpGet("Stats")]
    public async Task<IActionResult> Stats()
    {
        ViewData["Title"] = "Platform Overview";
        var vm = new AdminStatsVm();
        using var conn = _factory.CreateMasterConnection();
        using var grid = await conn.QueryMultipleAsync("sp_Admin_GetStats", commandType: CommandType.StoredProcedure);
        vm.Counters     = await grid.ReadSingleAsync<AdminStatsCounters>();
        vm.PlanBreakdown = (await grid.ReadAsync<PlanBreakdownRow>()).ToList();
        vm.RecentSignups = (await grid.ReadAsync<RecentSignupRow>()).ToList();
        return View(vm);
    }

    // ─────────────────────── Companies ──────────────────────────
    [HttpGet("Companies")]
    public async Task<IActionResult> Companies(string? status, string? q)
    {
        ViewData["Title"] = "Companies";
        var all = await _companies.GetAllAsync();
        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<CompanyStatus>(status, true, out var s))
            all = all.Where(c => c.Status == s);
        if (!string.IsNullOrWhiteSpace(q))
        {
            var needle = q.Trim().ToLowerInvariant();
            all = all.Where(c =>
                c.Name.ToLowerInvariant().Contains(needle) ||
                c.Slug.ToLowerInvariant().Contains(needle) ||
                (c.Email ?? "").ToLowerInvariant().Contains(needle));
        }
        ViewBag.StatusFilter = status;
        ViewBag.Q = q;
        return View(all.ToList());
    }

    [HttpGet("Companies/Edit/{id:int}")]
    public async Task<IActionResult> EditCompany(int id)
    {
        var c = await _companies.GetByIdAsync(id);
        if (c == null) return NotFound();
        ViewData["Title"] = $"Edit — {c.Name}";
        ViewBag.Plans = await _plans.GetAllAsync(includeInactive: true);
        return View(c);
    }

    [HttpPost("Companies/Edit/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> EditCompany(int id, Company model)
    {
        var existing = await _companies.GetByIdAsync(id);
        if (existing == null) return NotFound();

        // Save the basic profile (Name/Email/Phone/Address/...)
        existing.Name           = model.Name?.Trim() ?? existing.Name;
        existing.Email          = model.Email ?? "";
        existing.Phone          = model.Phone ?? "";
        existing.Address        = model.Address ?? "";
        existing.City           = model.City ?? "";
        existing.Country        = string.IsNullOrWhiteSpace(model.Country) ? existing.Country : model.Country;
        existing.LicenseNumber  = model.LicenseNumber ?? "";
        existing.TaxNumber      = model.TaxNumber ?? "";
        existing.TimeZone       = string.IsNullOrWhiteSpace(model.TimeZone)       ? existing.TimeZone       : model.TimeZone;
        existing.Currency       = string.IsNullOrWhiteSpace(model.Currency)       ? existing.Currency       : model.Currency;
        existing.CurrencySymbol = string.IsNullOrWhiteSpace(model.CurrencySymbol) ? existing.CurrencySymbol : model.CurrencySymbol;
        await _companies.UpdateProfileAsync(existing, CurrentUserId);

        // Save the billing block (Plan / MaxUsers / Trial / Subscription)
        await _companies.UpdateBillingAsync(id,
            string.IsNullOrWhiteSpace(model.PlanName) ? existing.PlanName : model.PlanName,
            model.MaxUsers <= 0 ? existing.MaxUsers : model.MaxUsers,
            model.TrialEndsAt == default ? null : model.TrialEndsAt,
            model.SubscriptionEndsAt,
            CurrentUserId);

        TempData["Success"] = $"Saved {existing.Name}.";
        return RedirectToAction(nameof(Companies));
    }

    [HttpPost("Companies/SetStatus/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> SetCompanyStatus(int id, CompanyStatus status)
    {
        await _companies.UpdateStatusAsync(id, status, CurrentUserId);
        TempData["Success"] = $"Status set to {status}.";
        return RedirectToAction(nameof(Companies));
    }

    [HttpPost("Companies/Delete/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteCompany(int id)
    {
        await _companies.SoftDeleteAsync(id, CurrentUserId);
        TempData["Success"] = "Company removed (soft-deleted).";
        return RedirectToAction(nameof(Companies));
    }

    // ─────────────────────── Plans ──────────────────────────────
    [HttpGet("Plans")]
    public async Task<IActionResult> Plans()
    {
        ViewData["Title"] = "Subscription Plans";
        return View((await _plans.GetAllAsync(includeInactive: true)).ToList());
    }

    [HttpGet("Plans/Create")]
    public IActionResult CreatePlan()
    {
        ViewData["Title"] = "New Plan";
        return View("PlanForm", new SubscriptionPlan { IsActive = true, MaxUsers = 10 });
    }

    [HttpPost("Plans/Create"), ValidateAntiForgeryToken]
    public async Task<IActionResult> CreatePlan(SubscriptionPlan model)
    {
        if (!ModelState.IsValid) return View("PlanForm", model);
        await _plans.InsertAsync(model);
        TempData["Success"] = $"Plan '{model.Name}' created.";
        return RedirectToAction(nameof(Plans));
    }

    [HttpGet("Plans/Edit/{id:int}")]
    public async Task<IActionResult> EditPlan(int id)
    {
        var p = await _plans.GetByIdAsync(id);
        if (p == null) return NotFound();
        ViewData["Title"] = $"Edit — {p.Name}";
        return View("PlanForm", p);
    }

    [HttpPost("Plans/Edit/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> EditPlan(int id, SubscriptionPlan model)
    {
        if (!ModelState.IsValid) return View("PlanForm", model);
        model.Id = id;
        await _plans.UpdateAsync(model);
        TempData["Success"] = $"Plan '{model.Name}' updated.";
        return RedirectToAction(nameof(Plans));
    }

    [HttpPost("Plans/SetActive/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> SetPlanActive(int id, bool isActive)
    {
        await _plans.SetActiveAsync(id, isActive);
        return RedirectToAction(nameof(Plans));
    }

    [HttpPost("Plans/Delete/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> DeletePlan(int id)
    {
        await _plans.DeleteAsync(id);
        TempData["Success"] = "Plan deleted.";
        return RedirectToAction(nameof(Plans));
    }

    // ─────────────────────── View models ────────────────────────
    public class AdminStatsVm
    {
        public AdminStatsCounters Counters { get; set; } = new();
        public List<PlanBreakdownRow> PlanBreakdown { get; set; } = new();
        public List<RecentSignupRow> RecentSignups { get; set; } = new();
    }

    public class AdminStatsCounters
    {
        public int TotalCompanies { get; set; }
        public int ActiveCount { get; set; }
        public int SuspendedCount { get; set; }
        public int TrialCount { get; set; }
        public int ExpiredCount { get; set; }
        public int Signups30d { get; set; }
        public decimal MRR { get; set; }
    }

    public class PlanBreakdownRow
    {
        public string PlanName { get; set; } = "";
        public int CompanyCount { get; set; }
    }

    public class RecentSignupRow
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Slug { get; set; } = "";
        public string? Email { get; set; }
        public CompanyStatus Status { get; set; }
        public string PlanName { get; set; } = "";
        public DateTime CreatedAt { get; set; }
    }
}
