using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class ReportsController : Controller
{
    private readonly IDashboardRepository _dashboard;
    private readonly IBookingRepository _bookings;
    private readonly ITenantContext _tenant;

    public ReportsController(IDashboardRepository dashboard, IBookingRepository bookings, ITenantContext tenant)
    {
        _dashboard = dashboard;
        _bookings = bookings;
        _tenant = tenant;
    }

    public IActionResult Index()
    {
        ViewData["Title"] = "Reports";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Reports", null) };
        return View();
    }

    public async Task<IActionResult> Revenue(int year = 0)
    {
        if (year == 0) year = DateTime.Now.Year;
        ViewData["Title"] = $"Revenue Report {year}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Reports", "/Reports"), ("Revenue", null) };
        ViewBag.Year = year;
        ViewBag.CurrencySymbol = _tenant.CurrencySymbol;
        ViewBag.MonthlyRevenue = await _dashboard.GetMonthlyRevenueAsync(year);
        ViewBag.TopPackages = await _dashboard.GetTopPackagesAsync(10);
        return View();
    }

    public async Task<IActionResult> Bookings(DateTime? from, DateTime? to)
    {
        from ??= new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1);
        to   ??= DateTime.Today;
        ViewData["Title"] = "Bookings Report";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Reports", "/Reports"), ("Bookings", null) };
        ViewBag.From = from;
        ViewBag.To = to;
        ViewBag.CurrencySymbol = _tenant.CurrencySymbol;
        ViewBag.Bookings = await _bookings.GetByDateRangeAsync(from.Value, to.Value);
        return View();
    }
}
