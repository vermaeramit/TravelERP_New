using System.Data;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;
using TravelERP.Web.Models;

namespace TravelERP.Web.Controllers;

[Authorize]
public class DashboardController : Controller
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;
    private readonly ICompanyRepository _companies;

    public DashboardController(DbConnectionFactory factory, ITenantContext tenant, ICompanyRepository companies)
    {
        _factory = factory;
        _tenant = tenant;
        _companies = companies;
    }

    public async Task<IActionResult> Index()
    {
        // Platform admin doesn't belong to a tenant — bounce them to the admin portal.
        if (User.IsInRole("SuperAdmin"))
            return RedirectToAction("Stats", "Admin");

        ViewData["Title"] = "Dashboard";
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);

        var vm = new DashboardVm
        {
            Currency = company?.Currency ?? "INR"
        };

        using var conn = _factory.CreateMasterConnection();
        using var multi = await conn.QueryMultipleAsync(
            "sp_Dashboard_GetSummary",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);

        vm.Kpis                = await multi.ReadSingleOrDefaultAsync<DashboardKpis>() ?? new DashboardKpis();
        vm.RevenueTrend        = (await multi.ReadAsync<RevenuePoint>()).ToList();
        vm.LeadsByStatus       = (await multi.ReadAsync<LeadStatusSlice>()).ToList();
        vm.RecentLeads         = (await multi.ReadAsync<RecentLead>()).ToList();
        vm.UpcomingTravel      = (await multi.ReadAsync<UpcomingBooking>()).ToList();
        vm.OverdueInstallments = (await multi.ReadAsync<OverdueInstallment>()).ToList();

        return View(vm);
    }

    [HttpGet]
    public async Task<IActionResult> MonthlyBreakdown(int? year)
    {
        if (year is null or < 2000 or > 2100) year = DateTime.UtcNow.Year;

        using var conn = _factory.CreateMasterConnection();
        using var multi = await conn.QueryMultipleAsync(
            "sp_Dashboard_GetMonthlyBreakdown",
            new { DatabaseName = _tenant.DatabaseName, Year = year },
            commandType: CommandType.StoredProcedure);

        var totals   = (await multi.ReadAsync<MonthlyTotals>()).ToList();
        var byStatus = (await multi.ReadAsync<MonthlyStatus>()).ToList();

        return Json(new { year, totals, byStatus });
    }

    [HttpGet]
    public async Task<IActionResult> RangeSummary(DateTime? from, DateTime? to)
    {
        var endDate = to ?? DateTime.UtcNow.Date;
        var startDate = from ?? endDate.AddDays(-6);
        if (endDate < startDate) (startDate, endDate) = (endDate, startDate);

        using var conn = _factory.CreateMasterConnection();
        using var multi = await conn.QueryMultipleAsync(
            "sp_Dashboard_GetRangeSummary",
            new { DatabaseName = _tenant.DatabaseName, StartDate = startDate.Date, EndDate = endDate.Date },
            commandType: CommandType.StoredProcedure);

        var totals = await multi.ReadSingleOrDefaultAsync<RangeTotals>() ?? new RangeTotals();
        var pie    = (await multi.ReadAsync<LeadStatusSlice>()).ToList();

        return Json(new
        {
            from = startDate.ToString("yyyy-MM-dd"),
            to   = endDate.ToString("yyyy-MM-dd"),
            totals,
            pie
        });
    }
}
