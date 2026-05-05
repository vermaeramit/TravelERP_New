using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class DashboardController : Controller
{
    private readonly IDashboardRepository _dashboard;
    private readonly ITenantContext _tenant;

    public DashboardController(IDashboardRepository dashboard, ITenantContext tenant)
    {
        _dashboard = dashboard;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        ViewData["Title"] = "Dashboard";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Dashboard", null) };

        var stats = await _dashboard.GetStatsAsync();
        var recentBookings = await _dashboard.GetRecentBookingsAsync(10);
        var topPackages = await _dashboard.GetTopPackagesAsync(5);
        var monthlyRevenue = await _dashboard.GetMonthlyRevenueAsync(DateTime.Now.Year);
        var statusChart = await _dashboard.GetBookingStatusChartAsync();

        ViewBag.Stats = stats;
        ViewBag.RecentBookings = recentBookings;
        ViewBag.TopPackages = topPackages;
        ViewBag.MonthlyRevenue = monthlyRevenue;
        ViewBag.StatusChart = statusChart;
        ViewBag.CurrencySymbol = _tenant.CurrencySymbol;

        return View();
    }
}
