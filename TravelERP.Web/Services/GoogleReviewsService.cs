using System.Net;
using System.Text.Json;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Services;

/// <summary>
/// Fetches Google Business reviews for a tenant company and caches the API response
/// in the Companies row to avoid hitting Places API on every public package page view.
/// Cache TTL is 12 hours — on a stale or missing cache the next public view triggers
/// a refresh inline (no background worker needed for low-volume traffic).
/// </summary>
public class GoogleReviewsService
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(12);
    private static readonly HttpClient _http = new()
    {
        Timeout = TimeSpan.FromSeconds(8)
    };

    private readonly ICompanyRepository _companies;
    private readonly ILogger<GoogleReviewsService> _log;

    public GoogleReviewsService(ICompanyRepository companies, ILogger<GoogleReviewsService> log)
    {
        _companies = companies;
        _log = log;
    }

    public record ReviewItem(
        string AuthorName,
        string? ProfilePhotoUrl,
        int Rating,
        string? RelativeTime,
        string? Text);

    public record ReviewsBundle(
        double? AverageRating,
        int? TotalRatings,
        IReadOnlyList<ReviewItem> Reviews);

    /// <summary>
    /// Returns up to 5 reviews for the given company, using cache when fresh.
    /// Returns <c>null</c> if the company hasn't configured Place ID + API key.
    /// </summary>
    public async Task<ReviewsBundle?> GetReviewsAsync(Company company)
    {
        if (string.IsNullOrWhiteSpace(company.GooglePlaceId) ||
            string.IsNullOrWhiteSpace(company.GoogleApiKey))
            return null;

        var now = DateTime.UtcNow;
        var fresh = company.GoogleReviewsCachedAt.HasValue &&
                    (now - company.GoogleReviewsCachedAt.Value) < CacheTtl;

        if (fresh && !string.IsNullOrWhiteSpace(company.GoogleReviewsCacheJson))
        {
            var cached = ParseBundle(company.GoogleReviewsCacheJson);
            if (cached != null) return cached;
        }

        // Fetch from Places Details API
        try
        {
            var url = "https://maps.googleapis.com/maps/api/place/details/json"
                    + "?place_id=" + WebUtility.UrlEncode(company.GooglePlaceId)
                    + "&fields=reviews,rating,user_ratings_total"
                    + "&reviews_sort=newest"
                    + "&key=" + WebUtility.UrlEncode(company.GoogleApiKey);

            var json = await _http.GetStringAsync(url);
            var bundle = ParseBundle(json);
            // Always cache the raw response (even empty) so we don't hammer the API on errors.
            await _companies.UpdateGoogleReviewsCacheAsync(company.Id, json, now);
            return bundle;
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Google Places fetch failed for company {CompanyId}", company.Id);
            // Fall back to whatever stale cache we have — better stale than nothing.
            return string.IsNullOrWhiteSpace(company.GoogleReviewsCacheJson)
                ? null
                : ParseBundle(company.GoogleReviewsCacheJson);
        }
    }

    private static ReviewsBundle? ParseBundle(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (!doc.RootElement.TryGetProperty("result", out var result)
                || result.ValueKind != JsonValueKind.Object)
                return null;

            double? avg = result.TryGetProperty("rating", out var r) && r.ValueKind == JsonValueKind.Number
                ? r.GetDouble() : null;
            int? total = result.TryGetProperty("user_ratings_total", out var u) && u.ValueKind == JsonValueKind.Number
                ? u.GetInt32() : null;

            var list = new List<ReviewItem>();
            if (result.TryGetProperty("reviews", out var reviews) && reviews.ValueKind == JsonValueKind.Array)
            {
                foreach (var rv in reviews.EnumerateArray())
                {
                    var author = rv.TryGetProperty("author_name", out var a) ? a.GetString() : null;
                    if (string.IsNullOrWhiteSpace(author)) continue;
                    var photo  = rv.TryGetProperty("profile_photo_url", out var p) ? p.GetString() : null;
                    var rating = rv.TryGetProperty("rating", out var rr) && rr.ValueKind == JsonValueKind.Number
                        ? rr.GetInt32() : 0;
                    var rel    = rv.TryGetProperty("relative_time_description", out var rt) ? rt.GetString() : null;
                    var text   = rv.TryGetProperty("text", out var tx) ? tx.GetString() : null;
                    list.Add(new ReviewItem(author!, photo, rating, rel, text));
                }
            }
            return new ReviewsBundle(avg, total, list);
        }
        catch
        {
            return null;
        }
    }
}
