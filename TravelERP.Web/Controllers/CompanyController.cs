using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize(Roles = "SuperAdmin,CompanyAdmin")]
[Route("[controller]")]
public class CompanyController : Controller
{
    private readonly ICompanyRepository _companies;
    private readonly IUserRepository _users;
    private readonly ITenantContext _tenant;
    private readonly IWebHostEnvironment _env;

    private static readonly string[] AllowedLogoExt = [".jpg", ".jpeg", ".png", ".webp", ".svg"];
    private const long MaxLogoBytes = 2 * 1024 * 1024;   // 2 MB

    public CompanyController(ICompanyRepository companies, IUserRepository users, ITenantContext tenant, IWebHostEnvironment env)
    {
        _companies = companies;
        _users = users;
        _tenant = tenant;
        _env = env;
    }

    [HttpGet("Settings")]
    public async Task<IActionResult> Settings()
    {
        ViewData["Title"] = "Company Settings";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Setup", null), ("Settings", null) };
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        return View(company);
    }

    [HttpPost("Settings")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Settings(TravelERP.Core.Entities.Master.Company model)
    {
        if (!ModelState.IsValid) return View(model);
        model.UpdatedBy = _tenant.UserId;
        model.UpdatedAt = DateTime.UtcNow;
        await _companies.UpdateAsync(model);
        TempData["Success"] = "Company settings saved.";
        return RedirectToAction(nameof(Settings));
    }

    [HttpGet("Users")]
    public async Task<IActionResult> Users()
    {
        ViewData["Title"] = "User Management";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Setup", null), ("Users", null) };
        var users = await _users.GetByCompanyAsync(_tenant.CompanyId);
        return View(users);
    }

    [HttpGet("Branches")]
    public IActionResult Branches()
    {
        ViewData["Title"] = "Branches";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Setup", null), ("Branches", null) };
        return View();
    }

    [HttpGet("QuoteBranding")]
    public async Task<IActionResult> QuoteBranding()
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        ViewData["Title"] = "Quote Branding";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Setup", null), ("Quote Branding", null) };
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        return View(company);
    }

    [HttpPost("QuoteBranding"), ValidateAntiForgeryToken]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<IActionResult> QuoteBranding(
        string? greetingParagraph,
        string? whyBookWithUs,
        IFormFile? logoFile,
        bool removeLogo = false)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();

        string? logoUrl   = null;
        bool    updateLogo = false;

        if (removeLogo)
        {
            updateLogo = true;
            logoUrl    = null;
        }
        else if (logoFile is { Length: > 0 })
        {
            var saved = await SaveLogoAsync(logoFile);
            if (saved == null)
            {
                TempData["Error"] = "Logo upload failed — must be JPG/PNG/WebP/SVG under 2 MB.";
                return RedirectToAction(nameof(QuoteBranding));
            }
            logoUrl    = saved;
            updateLogo = true;
        }

        await _companies.UpdateQuoteBrandingAsync(
            _tenant.CompanyId, greetingParagraph, whyBookWithUs, logoUrl, updateLogo, _tenant.UserId);
        TempData["Success"] = "Quote branding saved.";
        return RedirectToAction(nameof(QuoteBranding));
    }

    private async Task<string?> SaveLogoAsync(IFormFile file)
    {
        if (file.Length == 0 || file.Length > MaxLogoBytes) return null;
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedLogoExt.Contains(ext)) return null;

        var folder = Path.Combine(_env.WebRootPath, "uploads", "company");
        Directory.CreateDirectory(folder);

        var fileName = $"logo-{_tenant.CompanyId}-{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(folder, fileName);
        await using var fs = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(fs);

        return $"/uploads/company/{fileName}";
    }

    [HttpGet("NumberSeries")]
    public async Task<IActionResult> NumberSeries()
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        ViewData["Title"] = "Number Series";
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        return View(company);
    }

    [HttpPost("NumberSeries"), ValidateAntiForgeryToken]
    public async Task<IActionResult> NumberSeries(string leadPrefix, string packagePrefix, string bookingPrefix, string invoicePrefix)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();

        leadPrefix    = (leadPrefix    ?? "").Trim().ToUpperInvariant();
        packagePrefix = (packagePrefix ?? "").Trim().ToUpperInvariant();
        bookingPrefix = (bookingPrefix ?? "").Trim().ToUpperInvariant();
        invoicePrefix = (invoicePrefix ?? "").Trim().ToUpperInvariant();

        var all = new[] { leadPrefix, packagePrefix, bookingPrefix, invoicePrefix };
        if (all.Any(string.IsNullOrEmpty))
        {
            TempData["Error"] = "All prefixes are required.";
            return RedirectToAction(nameof(NumberSeries));
        }
        if (all.Any(p => p.Length > 20))
        {
            TempData["Error"] = "Prefix max length is 20 characters.";
            return RedirectToAction(nameof(NumberSeries));
        }

        await _companies.UpdateNumberSeriesAsync(_tenant.CompanyId, leadPrefix, packagePrefix, bookingPrefix, invoicePrefix, _tenant.UserId);
        TempData["Success"] = "Number series updated. New records will use the new prefixes.";
        return RedirectToAction(nameof(NumberSeries));
    }
}
