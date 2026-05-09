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

    [HttpGet("VoucherDefaults")]
    public async Task<IActionResult> VoucherDefaults()
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        ViewData["Title"] = "Voucher Defaults";
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        return View(company);
    }

    [HttpPost("VoucherDefaults"), ValidateAntiForgeryToken]
    public async Task<IActionResult> VoucherDefaults(
        string? checkInTime, string? checkOutTime,
        string? hotelNote, string? policyHtml)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        var existing = await _companies.GetByIdAsync(_tenant.CompanyId);
        if (existing == null) return NotFound();

        existing.VoucherCheckInTime  = string.IsNullOrWhiteSpace(checkInTime)  ? null : checkInTime.Trim();
        existing.VoucherCheckOutTime = string.IsNullOrWhiteSpace(checkOutTime) ? null : checkOutTime.Trim();
        existing.VoucherHotelNote    = string.IsNullOrWhiteSpace(hotelNote)    ? null : hotelNote;
        existing.VoucherPolicyHtml   = string.IsNullOrWhiteSpace(policyHtml)   ? null : policyHtml;

        await _companies.UpdateVoucherDefaultsAsync(_tenant.CompanyId, existing, _tenant.UserId);
        TempData["Success"] = "Voucher defaults saved.";
        return RedirectToAction(nameof(VoucherDefaults));
    }

    [HttpGet("EmailSettings")]
    public async Task<IActionResult> EmailSettings()
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        ViewData["Title"] = "Email Settings";
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        return View(company);
    }

    [HttpPost("EmailSettings"), ValidateAntiForgeryToken]
    public async Task<IActionResult> EmailSettings(TravelERP.Core.Entities.Master.Company model)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();

        // We only persist the SMTP block — leave the rest of the company alone.
        var existing = await _companies.GetByIdAsync(_tenant.CompanyId);
        if (existing == null) return NotFound();

        existing.SmtpHost      = model.SmtpHost?.Trim();
        existing.SmtpPort      = model.SmtpPort;
        existing.SmtpUsername  = model.SmtpUsername?.Trim();
        // Empty password = keep existing (don't blank it out on every save)
        if (!string.IsNullOrWhiteSpace(model.SmtpPassword)) existing.SmtpPassword = model.SmtpPassword;
        existing.SmtpFromEmail = model.SmtpFromEmail?.Trim();
        existing.SmtpFromName  = model.SmtpFromName?.Trim();
        existing.SmtpUseTls    = model.SmtpUseTls;

        await _companies.UpdateEmailSettingsAsync(_tenant.CompanyId, existing, _tenant.UserId);
        TempData["Success"] = "Email settings saved.";
        return RedirectToAction(nameof(EmailSettings));
    }

    [HttpPost("EmailSettings/TestSend"), ValidateAntiForgeryToken]
    public async Task<IActionResult> TestSendEmail(
        [FromServices] TravelERP.Web.Services.EmailService emailService,
        string testTo)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        if (company == null) return NotFound();

        if (string.IsNullOrWhiteSpace(testTo))
            return Json(new { success = false, error = "Recipient is required." });

        var result = await emailService.SendAsync(
            company,
            toEmail: testTo,
            subject: $"Test email from {company.Name}",
            htmlBody: $"<p>This is a test email sent from <strong>{company.Name}</strong> to confirm your SMTP configuration is working.</p><p>If you received this, you're all set.</p>");

        return Json(new { success = result.Success, error = result.ErrorMessage });
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
