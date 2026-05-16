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
        model.Id = _tenant.CompanyId;   // make sure we update the current tenant, not whatever the form posted
        await _companies.UpdateProfileAsync(model, _tenant.UserId);
        TempData["Success"] = "Company settings saved.";
        return RedirectToAction(nameof(Settings));
    }

    [HttpGet("Users")]
    public async Task<IActionResult> Users()
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        ViewData["Title"] = "Users";
        var users = (await _users.GetByCompanyAsync(_tenant.CompanyId)).ToList();
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        ViewBag.ActiveCount = users.Count(u => u.IsActive);
        ViewBag.MaxUsers    = company?.MaxUsers ?? 0;
        ViewBag.PlanName    = company?.PlanName ?? "";
        return View(users);
    }

    [HttpGet("Users/Create")]
    public async Task<IActionResult> CreateUser([FromServices] IRoleRepository roles)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        ViewData["Title"] = "Add User";
        ViewBag.Roles = await roles.GetAllAsync();
        return View("UserForm", new UserFormVm());
    }

    [HttpPost("Users/Create"), ValidateAntiForgeryToken]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> CreateUser(
        UserFormVm vm, IFormFile? photo,
        [FromServices] IRoleRepository roles)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        if (!ModelState.IsValid)
        {
            ViewBag.Roles = await roles.GetAllAsync();
            return View("UserForm", vm);
        }

        // Check for duplicate email across all companies (MasterUsers.Email is unique)
        var existing = await _users.GetByEmailAsync(vm.Email);
        if (existing != null)
        {
            ModelState.AddModelError(nameof(vm.Email), "A user with this email already exists.");
            ViewBag.Roles = await roles.GetAllAsync();
            return View("UserForm", vm);
        }

        if (string.IsNullOrWhiteSpace(vm.Password) || vm.Password.Length < 6)
        {
            ModelState.AddModelError(nameof(vm.Password), "Password must be at least 6 characters.");
            ViewBag.Roles = await roles.GetAllAsync();
            return View("UserForm", vm);
        }

        // Enforce plan user-limit (only counts active users; disabled users don't consume a seat).
        if (vm.IsActive)
        {
            var company = await _companies.GetByIdAsync(_tenant.CompanyId);
            var activeCount = (await _users.GetByCompanyAsync(_tenant.CompanyId)).Count(u => u.IsActive);
            if (company != null && activeCount >= company.MaxUsers)
            {
                ModelState.AddModelError("", $"User limit reached: your {company.PlanName} plan allows {company.MaxUsers} active users (currently {activeCount}). Upgrade the plan or deactivate an existing user.");
                ViewBag.Roles = await roles.GetAllAsync();
                return View("UserForm", vm);
            }
        }

        var imageUrl = await SaveUserPhotoAsync(photo);

        var user = new TravelERP.Core.Entities.Master.MasterUser
        {
            CompanyId       = _tenant.CompanyId,
            FullName        = vm.FullName.Trim(),
            Email           = vm.Email.Trim().ToLowerInvariant(),
            PasswordHash    = BCrypt.Net.BCrypt.HashPassword(vm.Password),
            Role            = vm.Role,
            IsActive        = vm.IsActive,
            ProfileImageUrl = imageUrl,
            Mobile          = string.IsNullOrWhiteSpace(vm.Mobile) ? null : vm.Mobile.Trim(),
            DateOfBirth     = vm.DateOfBirth,
            ReplyEmail      = string.IsNullOrWhiteSpace(vm.ReplyEmail) ? null : vm.ReplyEmail.Trim(),
            CreatedBy       = _tenant.UserId,
            CreatedAt       = DateTime.UtcNow
        };
        var newId = await _users.InsertAsync(user);
        if (vm.TenantRoleId.HasValue && vm.TenantRoleId > 0)
            await _users.SetTenantRoleAsync(newId, vm.TenantRoleId.Value);

        TempData["Success"] = $"User {user.FullName} created.";
        return RedirectToAction(nameof(Users));
    }

    [HttpGet("Users/Edit/{id:int}")]
    public async Task<IActionResult> EditUser(int id, [FromServices] IRoleRepository roles)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        var user = await _users.GetByIdAsync(id);
        if (user == null || user.CompanyId != _tenant.CompanyId) return NotFound();
        ViewData["Title"] = $"Edit — {user.FullName}";
        ViewBag.Roles = await roles.GetAllAsync();
        return View("UserForm", new UserFormVm
        {
            Id           = user.Id,
            FullName     = user.FullName,
            Email        = user.Email,
            Role         = user.Role,
            TenantRoleId = user.TenantRoleId,
            IsActive     = user.IsActive,
            Mobile       = user.Mobile,
            DateOfBirth  = user.DateOfBirth,
            ReplyEmail   = user.ReplyEmail,
            ImageUrl     = user.ProfileImageUrl
        });
    }

    [HttpPost("Users/Edit/{id:int}"), ValidateAntiForgeryToken]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> EditUser(int id,
        UserFormVm vm, IFormFile? photo,
        [FromServices] IRoleRepository roles)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        var user = await _users.GetByIdAsync(id);
        if (user == null || user.CompanyId != _tenant.CompanyId) return NotFound();

        if (!ModelState.IsValid)
        {
            ViewBag.Roles = await roles.GetAllAsync();
            return View("UserForm", vm);
        }

        var newImage = await SaveUserPhotoAsync(photo);

        user.FullName    = vm.FullName.Trim();
        user.Email       = vm.Email.Trim().ToLowerInvariant();
        user.Role        = vm.Role;
        user.IsActive    = vm.IsActive;
        user.Mobile      = string.IsNullOrWhiteSpace(vm.Mobile) ? null : vm.Mobile.Trim();
        user.DateOfBirth = vm.DateOfBirth;
        user.ReplyEmail  = string.IsNullOrWhiteSpace(vm.ReplyEmail) ? null : vm.ReplyEmail.Trim();
        if (newImage != null) user.ProfileImageUrl = newImage;
        user.UpdatedBy = _tenant.UserId;
        user.UpdatedAt = DateTime.UtcNow;
        await _users.UpdateAsync(user);
        if (vm.TenantRoleId.HasValue && vm.TenantRoleId > 0)
            await _users.SetTenantRoleAsync(id, vm.TenantRoleId.Value);

        TempData["Success"] = "User updated.";
        return RedirectToAction(nameof(Users));
    }

    private static readonly string[] AllowedPhotoExt = [".jpg", ".jpeg", ".png", ".webp", ".gif"];
    private const long MaxPhotoBytes = 5 * 1024 * 1024;

    private async Task<string?> SaveUserPhotoAsync(IFormFile? file)
    {
        if (file == null || file.Length == 0 || file.Length > MaxPhotoBytes) return null;
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedPhotoExt.Contains(ext)) return null;

        var folder = Path.Combine(_env.WebRootPath, "uploads", "users");
        Directory.CreateDirectory(folder);
        var fileName = $"u-{_tenant.CompanyId}-{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(folder, fileName);
        await using var fs = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(fs);
        return $"/uploads/users/{fileName}";
    }

    [HttpPost("Users/ResetPassword/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetUserPassword(int id, string newPassword)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        var user = await _users.GetByIdAsync(id);
        if (user == null || user.CompanyId != _tenant.CompanyId) return NotFound();

        if (string.IsNullOrWhiteSpace(newPassword) || newPassword.Length < 6)
        {
            TempData["Error"] = "New password must be at least 6 characters.";
            return RedirectToAction(nameof(Users));
        }

        await _users.ChangePasswordAsync(id, BCrypt.Net.BCrypt.HashPassword(newPassword));
        TempData["Success"] = $"Password reset for {user.FullName}.";
        return RedirectToAction(nameof(Users));
    }

    [HttpPost("Users/ToggleActive/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> ToggleUserActive(int id)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        var user = await _users.GetByIdAsync(id);
        if (user == null || user.CompanyId != _tenant.CompanyId) return NotFound();
        if (user.Id == _tenant.UserId)
        {
            TempData["Error"] = "You cannot disable your own account.";
            return RedirectToAction(nameof(Users));
        }

        // Block re-activation if it would push us over the plan's seat cap.
        if (!user.IsActive)
        {
            var company = await _companies.GetByIdAsync(_tenant.CompanyId);
            var activeCount = (await _users.GetByCompanyAsync(_tenant.CompanyId)).Count(u => u.IsActive);
            if (company != null && activeCount >= company.MaxUsers)
            {
                TempData["Error"] = $"User limit reached ({activeCount} / {company.MaxUsers}). Deactivate another user first or upgrade the {company.PlanName} plan.";
                return RedirectToAction(nameof(Users));
            }
        }

        user.IsActive = !user.IsActive;
        user.UpdatedBy = _tenant.UserId;
        user.UpdatedAt = DateTime.UtcNow;
        await _users.UpdateAsync(user);

        TempData["Success"] = user.IsActive ? $"{user.FullName} re-activated." : $"{user.FullName} deactivated.";
        return RedirectToAction(nameof(Users));
    }

    [HttpPost("Users/Delete/{id:int}"), ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteUser(int id)
    {
        if (!_tenant.IsSuperAdmin) return Forbid();
        var user = await _users.GetByIdAsync(id);
        if (user == null || user.CompanyId != _tenant.CompanyId) return NotFound();
        if (user.Id == _tenant.UserId)
        {
            TempData["Error"] = "You cannot delete your own account.";
            return RedirectToAction(nameof(Users));
        }
        await _users.DeleteAsync(id, _tenant.UserId);
        TempData["Success"] = $"{user.FullName} removed.";
        return RedirectToAction(nameof(Users));
    }

    public class UserFormVm
    {
        public int Id { get; set; }
        public string FullName { get; set; } = "";
        public string Email { get; set; } = "";
        public string? Password { get; set; }       // create-only
        public TravelERP.Shared.Enums.UserRole Role { get; set; } = TravelERP.Shared.Enums.UserRole.Agent;
        public int? TenantRoleId { get; set; }
        public bool IsActive { get; set; } = true;
        public string? Mobile { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? ReplyEmail { get; set; }
        public string? ImageUrl { get; set; }      // current photo URL (read-only display)
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
