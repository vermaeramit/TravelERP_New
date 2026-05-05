using System.Security.Claims;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Services;

public class TenantContext : ITenantContext
{
    private readonly IHttpContextAccessor _http;

    public TenantContext(IHttpContextAccessor http) => _http = http;

    private ClaimsPrincipal User => _http.HttpContext?.User
        ?? throw new InvalidOperationException("No HTTP context");

    public int CompanyId    => int.Parse(User.FindFirstValue("CompanyId") ?? "0");
    public string DatabaseName => User.FindFirstValue("DatabaseName") ?? "";
    public string CompanyName  => User.FindFirstValue("CompanyName")  ?? "";
    public string Currency     => User.FindFirstValue("Currency")     ?? "INR";
    public string CurrencySymbol => User.FindFirstValue("CurrencySymbol") ?? "₹";
    public int UserId        => int.Parse(User.FindFirstValue("UserId") ?? "0");
    public string UserFullName => User.FindFirstValue("FullName") ?? "";
    public string UserEmail    => User.FindFirstValue(ClaimTypes.Email) ?? "";
    public string UserRole     => User.FindFirstValue(ClaimTypes.Role) ?? "";
}
