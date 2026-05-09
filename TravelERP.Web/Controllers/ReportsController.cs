using System.Data;
using System.Globalization;
using System.Text;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;
using TravelERP.Web.Models;

namespace TravelERP.Web.Controllers;

[Authorize]
public class ReportsController : Controller
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;
    private readonly ICompanyRepository _companies;

    public ReportsController(DbConnectionFactory factory, ITenantContext tenant, ICompanyRepository companies)
    {
        _factory = factory;
        _tenant = tenant;
        _companies = companies;
    }

    public async Task<IActionResult> Index(DateTime? from, DateTime? to)
    {
        if (!_tenant.CanView(AppModules.Reports)) return Forbid();
        ViewData["Title"] = "Reports";

        var (start, end) = ResolveRange(from, to);
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);

        var vm = new ReportsVm
        {
            From = start,
            To   = end,
            Currency = company?.Currency ?? "INR"
        };

        using var conn = _factory.CreateMasterConnection();

        // Sales Summary (KPIs + monthly trend)
        using (var multi = await conn.QueryMultipleAsync(
            "sp_Report_SalesSummary",
            new { DatabaseName = _tenant.DatabaseName, From = start.Date, To = end.Date },
            commandType: CommandType.StoredProcedure))
        {
            vm.Summary      = await multi.ReadSingleOrDefaultAsync<SalesSummaryKpis>() ?? new();
            vm.MonthlyTrend = (await multi.ReadAsync<SalesMonthlyPoint>()).ToList();
        }

        vm.ByDestination = (await conn.QueryAsync<SalesByGroupRow>(
            "sp_Report_SalesByDestination",
            new { DatabaseName = _tenant.DatabaseName, From = start.Date, To = end.Date },
            commandType: CommandType.StoredProcedure)).ToList();

        vm.ByAgent = (await conn.QueryAsync<SalesByGroupRow>(
            "sp_Report_SalesByAgent",
            new { DatabaseName = _tenant.DatabaseName, From = start.Date, To = end.Date },
            commandType: CommandType.StoredProcedure)).ToList();

        using (var multi = await conn.QueryMultipleAsync(
            "sp_Report_PaymentAging",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure))
        {
            vm.AgingBuckets = (await multi.ReadAsync<AgingBucketRow>()).ToList();
            vm.AgingDetails = (await multi.ReadAsync<AgingDetailRow>()).ToList();
        }

        return View(vm);
    }

    // ───────────────────── CSV exports ─────────────────────

    [HttpGet("Reports/Export/Destinations")]
    public async Task<IActionResult> ExportDestinations(DateTime? from, DateTime? to)
    {
        if (!_tenant.CanView(AppModules.Reports)) return Forbid();
        var (start, end) = ResolveRange(from, to);
        using var conn = _factory.CreateMasterConnection();
        var rows = (await conn.QueryAsync<SalesByGroupRow>(
            "sp_Report_SalesByDestination",
            new { DatabaseName = _tenant.DatabaseName, From = start.Date, To = end.Date },
            commandType: CommandType.StoredProcedure)).ToList();

        var csv = BuildCsv(
            new[] { "Destination", "Bookings", "Total Revenue", "Avg Booking Value" },
            rows.Select(r => new[] {
                r.DestinationName,
                r.BookingCount.ToString(CultureInfo.InvariantCulture),
                r.TotalRevenue.ToString("F2", CultureInfo.InvariantCulture),
                r.AvgBookingValue.ToString("F2", CultureInfo.InvariantCulture)
            }));
        return CsvFile(csv, $"sales-by-destination_{start:yyyyMMdd}_{end:yyyyMMdd}.csv");
    }

    [HttpGet("Reports/Export/Agents")]
    public async Task<IActionResult> ExportAgents(DateTime? from, DateTime? to)
    {
        if (!_tenant.CanView(AppModules.Reports)) return Forbid();
        var (start, end) = ResolveRange(from, to);
        using var conn = _factory.CreateMasterConnection();
        var rows = (await conn.QueryAsync<SalesByGroupRow>(
            "sp_Report_SalesByAgent",
            new { DatabaseName = _tenant.DatabaseName, From = start.Date, To = end.Date },
            commandType: CommandType.StoredProcedure)).ToList();

        var csv = BuildCsv(
            new[] { "Agent", "Bookings", "Total Revenue", "Avg Booking Value" },
            rows.Select(r => new[] {
                r.AgentName,
                r.BookingCount.ToString(CultureInfo.InvariantCulture),
                r.TotalRevenue.ToString("F2", CultureInfo.InvariantCulture),
                r.AvgBookingValue.ToString("F2", CultureInfo.InvariantCulture)
            }));
        return CsvFile(csv, $"sales-by-agent_{start:yyyyMMdd}_{end:yyyyMMdd}.csv");
    }

    [HttpGet("Reports/Export/Aging")]
    public async Task<IActionResult> ExportAging()
    {
        if (!_tenant.CanView(AppModules.Reports)) return Forbid();
        using var conn = _factory.CreateMasterConnection();
        using var multi = await conn.QueryMultipleAsync(
            "sp_Report_PaymentAging",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
        await multi.ReadAsync<AgingBucketRow>();
        var rows = (await multi.ReadAsync<AgingDetailRow>()).ToList();

        var csv = BuildCsv(
            new[] { "Booking #", "Customer", "Installment", "Amount", "Currency", "Due Date", "Days Overdue" },
            rows.Select(r => new[] {
                r.BookingNumber,
                r.CustomerName,
                r.InstallmentNo.ToString(),
                r.Amount.ToString("F2", CultureInfo.InvariantCulture),
                r.Currency,
                r.DueDate?.ToString("yyyy-MM-dd") ?? "",
                r.DaysOverdue.ToString()
            }));
        return CsvFile(csv, $"payment-aging_{DateTime.UtcNow:yyyyMMdd}.csv");
    }

    // ───────────────────── helpers ─────────────────────

    private static (DateTime, DateTime) ResolveRange(DateTime? from, DateTime? to)
    {
        var end   = (to   ?? DateTime.UtcNow).Date;
        var start = (from ?? end.AddMonths(-1)).Date;
        if (end < start) (start, end) = (end, start);
        return (start, end);
    }

    private static string BuildCsv(string[] headers, IEnumerable<string[]> rows)
    {
        var sb = new StringBuilder();
        sb.AppendLine(string.Join(",", headers.Select(EscapeCsv)));
        foreach (var row in rows) sb.AppendLine(string.Join(",", row.Select(EscapeCsv)));
        return sb.ToString();
    }

    private static string EscapeCsv(string? s)
    {
        if (string.IsNullOrEmpty(s)) return "";
        var needsQuotes = s.Contains(',') || s.Contains('"') || s.Contains('\n') || s.Contains('\r');
        if (needsQuotes) return "\"" + s.Replace("\"", "\"\"") + "\"";
        return s;
    }

    private FileResult CsvFile(string csv, string fileName)
    {
        var bom = new byte[] { 0xEF, 0xBB, 0xBF };
        var body = Encoding.UTF8.GetBytes(csv);
        var bytes = new byte[bom.Length + body.Length];
        Buffer.BlockCopy(bom, 0, bytes, 0, bom.Length);
        Buffer.BlockCopy(body, 0, bytes, bom.Length, body.Length);
        return File(bytes, "text/csv", fileName);
    }
}
