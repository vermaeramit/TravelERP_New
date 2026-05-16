using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Services;

/// <summary>
/// Authorization filter that authenticates an incoming request via the X-Api-Key header.
/// Runs before model binding so unauthorized callers don't get 400s for missing fields —
/// they get a proper 401. On success, the resolved ApiKey (with joined Company info) is
/// placed on <c>HttpContext.Items["ApiKey"]</c> for the controller to read.
/// </summary>
public class ApiKeyAuthAttribute : Attribute, IAsyncAuthorizationFilter
{
    public const string ItemKey = "ApiKey";

    public async Task OnAuthorizationAsync(AuthorizationFilterContext ctx)
    {
        var http = ctx.HttpContext;
        if (!http.Request.Headers.TryGetValue("X-Api-Key", out var headerVal) || string.IsNullOrWhiteSpace(headerVal))
        {
            ctx.Result = new UnauthorizedObjectResult(new { error = "Missing X-Api-Key header." });
            return;
        }

        var repo = http.RequestServices.GetRequiredService<IApiKeyRepository>();
        var key = await repo.GetByKeyAsync(headerVal.ToString().Trim());
        if (key == null)
        {
            ctx.Result = new UnauthorizedObjectResult(new { error = "Invalid or revoked API key." });
            return;
        }
        if (key.ExpiresAt.HasValue && key.ExpiresAt.Value < DateTime.UtcNow)
        {
            ctx.Result = new UnauthorizedObjectResult(new { error = "API key has expired." });
            return;
        }
        // Block API calls for suspended/expired tenants (matches login behaviour).
        if (key.CompanyStatus.HasValue && (key.CompanyStatus.Value == 1 /* Suspended */ || key.CompanyStatus.Value == 3 /* Expired */))
        {
            ctx.Result = new ObjectResult(new { error = "Tenant account is not active." }) { StatusCode = 403 };
            return;
        }

        http.Items[ItemKey] = key;
        // Best-effort: bump LastUsedAt asynchronously so the response isn't blocked on it.
        _ = Task.Run(() => repo.MarkUsedAsync(key.Id));
    }
}
