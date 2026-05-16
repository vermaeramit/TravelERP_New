using System.Data;
using System.Text.Json;
using Dapper;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Web.Services;

/// <summary>
/// Read-only cross-DB lookup of a Package by company slug + share token.
/// Used by the public customer-facing /p/{slug}/{token} route — does NOT
/// depend on ITenantContext because public requests are unauthenticated.
/// </summary>
public class PublicPackageService
{
    private readonly DbConnectionFactory _factory;
    private readonly ICompanyRepository _companies;
    private readonly GoogleReviewsService _reviews;

    public PublicPackageService(DbConnectionFactory factory, ICompanyRepository companies, GoogleReviewsService reviews)
    {
        _factory = factory;
        _companies = companies;
        _reviews = reviews;
    }

    public record AgentInfo(string? FullName, string? Email, string? Mobile, string? ImageUrl);
    public record WhyItem(string Icon, string Title);

    public record PublicResult(
        Package Package,
        Company Company,
        AgentInfo? Agent,
        string? GreetingHtml,
        IReadOnlyList<WhyItem> WhyBookWithUs,
        IReadOnlyList<BankAccount> BankAccounts,
        GoogleReviewsService.ReviewsBundle? GoogleReviews);

    public async Task<PublicResult?> GetByShareTokenAsync(string companySlug, string token)
    {
        if (string.IsNullOrWhiteSpace(companySlug) || string.IsNullOrWhiteSpace(token))
            return null;

        var company = await _companies.GetBySlugAsync(companySlug.Trim().ToLowerInvariant());
        if (company == null) return null;

        using var conn = _factory.CreateMasterConnection();
        using var multi = await conn.QueryMultipleAsync(
            "sp_Package_GetByShareToken",
            new { DatabaseName = company.DatabaseName, Token = token.Trim() },
            commandType: CommandType.StoredProcedure);

        var package = await multi.ReadSingleOrDefaultAsync<Package>();
        if (package == null) return null;

        var options = (await multi.ReadAsync<PackageOption>()).ToList();
        var hotels  = (await multi.ReadAsync<PackageOptionHotel>()).ToList();
        foreach (var opt in options)
            opt.Hotels = hotels.Where(h => h.PackageOptionId == opt.Id).ToList();
        package.Options = options;

        var days = (await multi.ReadAsync<PackageDay>()).ToList();
        var dayLinks = (await multi.ReadAsync<dynamic>()).ToList();
        foreach (var d in days)
        {
            var rows = dayLinks.Where(r => (int)r.PackageDayId == d.Id).ToList();
            d.SightseeingIds    = rows.Select(r => (int)r.SightseeingId).ToList();
            d.SightseeingNames  = rows.Select(r => (string?)r.SightseeingName ?? "")
                                     .Where(s => s.Length > 0).ToList();
            d.SightseeingImages = rows.Select(r => (string?)r.SightseeingImageUrl ?? "")
                                     .Where(s => s.Length > 0).ToList();
        }
        package.ItineraryDays = days;

        var bankAccounts = (await multi.ReadAsync<BankAccount>()).ToList();

        var agentRow = await multi.ReadSingleOrDefaultAsync<AgentInfo>();

        var brandingRow = await multi.ReadSingleOrDefaultAsync<dynamic>();
        string? greeting = brandingRow?.GreetingParagraph as string;
        string? whyJson  = brandingRow?.WhyBookWithUs   as string;

        var whyItems = ParseWhyJson(whyJson);

        // Best-effort: pull cached Google reviews (or refresh if stale).
        // Service returns null when Place ID / API key aren't configured.
        var reviews = await _reviews.GetReviewsAsync(company);

        return new PublicResult(package, company, agentRow, greeting, whyItems, bankAccounts, reviews);
    }

    public static IReadOnlyList<WhyItem> ParseWhyJson(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return Array.Empty<WhyItem>();
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Array) return Array.Empty<WhyItem>();
            var list = new List<WhyItem>();
            foreach (var el in doc.RootElement.EnumerateArray())
            {
                var icon  = el.TryGetProperty("icon",  out var i) ? i.GetString() : null;
                var title = el.TryGetProperty("title", out var t) ? t.GetString() : null;
                if (!string.IsNullOrWhiteSpace(title))
                    list.Add(new WhyItem(icon ?? "bi-star", title!));
            }
            return list;
        }
        catch
        {
            return Array.Empty<WhyItem>();
        }
    }
}
