using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;
using TravelERP.Shared.DTOs;
using TravelERP.Web.Services;
using Dapper;
using System.Data;

namespace TravelERP.Web.Controllers;

[AllowAnonymous]
public class AuthController : Controller
{
    private const string PendingOtpSessionKey = "PendingOtp";
    // 6-digit OTP, 5-minute TTL, max 5 verify attempts, resend allowed after 30s.
    private static readonly TimeSpan OtpLifetime    = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan OtpResendCooldown = TimeSpan.FromSeconds(30);
    private const int MaxOtpAttempts = 5;

    private readonly IUserRepository _users;
    private readonly ICompanyRepository _companies;
    private readonly TenantDbProvisioningService _provisioner;
    private readonly DbConnectionFactory _dbFactory;
    private readonly EmailService _email;
    private readonly ILogger<AuthController> _log;

    public AuthController(IUserRepository users, ICompanyRepository companies,
        TenantDbProvisioningService provisioner, DbConnectionFactory dbFactory,
        EmailService email, ILogger<AuthController> log)
    {
        _users = users;
        _companies = companies;
        _provisioner = provisioner;
        _dbFactory = dbFactory;
        _email = email;
        _log = log;
    }

    // Holds the pending login between password-verified and OTP-verified pages.
    // Lives only in session; on logout/expiry it disappears.
    private record PendingOtpState(int UserId, int CompanyId, bool RememberMe, string ReturnUrl);

    [HttpGet("/login")]
    public IActionResult Login(string? returnUrl)
    {
        if (User.Identity?.IsAuthenticated == true) return RedirectToAction("Index", "Dashboard");
        ViewData["ReturnUrl"] = returnUrl;
        return View(new LoginDto());
    }

    [HttpPost("/login")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginDto model, string? returnUrl)
    {
        if (!ModelState.IsValid) return View(model);

        // Resolve company by code (slug) first
        var company = await _companies.GetBySlugAsync(model.CompanyCode.Trim().ToLower());
        if (company == null)
        {
            ModelState.AddModelError("CompanyCode", "Company code not found.");
            return View(model);
        }

        // Block login for Suspended / Expired companies (Active and Trial are allowed).
        // Platform tenant is always allowed regardless of status.
        if (!string.Equals(company.Slug, "platform", StringComparison.OrdinalIgnoreCase))
        {
            if (company.Status == TravelERP.Shared.Enums.CompanyStatus.Suspended)
            {
                ModelState.AddModelError("", "This company account is suspended. Please contact support.");
                return View(model);
            }
            if (company.Status == TravelERP.Shared.Enums.CompanyStatus.Expired)
            {
                ModelState.AddModelError("", "This company's subscription has expired. Please renew to continue.");
                return View(model);
            }
        }

        var user = await _users.GetByEmailAsync(model.Email);
        if (user == null || user.CompanyId != company.Id || !BCrypt.Net.BCrypt.Verify(model.Password, user.PasswordHash))
        {
            ModelState.AddModelError("", "Invalid email or password.");
            return View(model);
        }

        if (!user.IsActive)
        {
            ModelState.AddModelError("", "Your account is disabled. Contact your administrator.");
            return View(model);
        }

        // OTP gate — platform tenant is exempt (it has no per-tenant SMTP).
        var isPlatform = string.Equals(company.Slug, "platform", StringComparison.OrdinalIgnoreCase);
        if (company.RequireOtpLogin && !isPlatform)
        {
            var landing = user.Role == TravelERP.Shared.Enums.UserRole.SuperAdmin
                ? "/Admin/Stats"
                : (string.IsNullOrEmpty(returnUrl) ? "/Dashboard" : returnUrl);

            var state = new PendingOtpState(user.Id, company.Id, model.RememberMe, landing);
            HttpContext.Session.SetString(PendingOtpSessionKey,
                System.Text.Json.JsonSerializer.Serialize(state));

            var sendResult = await IssueAndSendOtpAsync(user, company);
            if (!sendResult.Success)
            {
                HttpContext.Session.Remove(PendingOtpSessionKey);
                ModelState.AddModelError("", "Couldn't send OTP email — " + sendResult.ErrorMessage);
                return View(model);
            }
            return RedirectToAction(nameof(Otp));
        }

        await _users.UpdateLastLoginAsync(user.Id);
        await SignInAsync(user, company, model.RememberMe);

        // Platform Super-Admin: skip the tenant Dashboard, go straight to the admin portal.
        if (user.Role == TravelERP.Shared.Enums.UserRole.SuperAdmin)
            return LocalRedirect("/Admin/Stats");

        return LocalRedirect(string.IsNullOrEmpty(returnUrl) ? "/Dashboard" : returnUrl);
    }

    // ─────────────────────────────────────────────── OTP login ───────────────────────────────────────────────

    [HttpGet("/otp")]
    public IActionResult Otp()
    {
        var state = LoadPendingOtp();
        if (state == null) return RedirectToAction(nameof(Login));
        ViewBag.Email = User.Identity?.Name; // not authenticated yet, but populated below from state
        ViewBag.MaskedEmail = MaskEmail(HttpContext.Session.GetString("PendingOtpEmail"));
        return View(new OtpVerifyDto());
    }

    [HttpPost("/otp")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Otp(OtpVerifyDto model)
    {
        var state = LoadPendingOtp();
        if (state == null) return RedirectToAction(nameof(Login));

        if (!ModelState.IsValid)
        {
            ViewBag.MaskedEmail = MaskEmail(HttpContext.Session.GetString("PendingOtpEmail"));
            return View(model);
        }

        var user = await _users.GetByIdAsync(state.UserId);
        var company = user != null ? await _companies.GetByIdAsync(state.CompanyId) : null;
        if (user == null || company == null)
        {
            HttpContext.Session.Remove(PendingOtpSessionKey);
            return RedirectToAction(nameof(Login));
        }

        if (!user.OtpExpiresAt.HasValue || user.OtpExpiresAt.Value < DateTime.UtcNow || string.IsNullOrEmpty(user.OtpHash))
        {
            ModelState.AddModelError("", "Your code has expired. Please request a new one.");
            ViewBag.MaskedEmail = MaskEmail(HttpContext.Session.GetString("PendingOtpEmail"));
            return View(model);
        }
        if (user.OtpAttempts >= MaxOtpAttempts)
        {
            await _users.ClearOtpAsync(user.Id);
            HttpContext.Session.Remove(PendingOtpSessionKey);
            ModelState.AddModelError("", "Too many incorrect attempts. Please log in again.");
            return RedirectToAction(nameof(Login));
        }

        var providedHash = HashOtp(model.Code.Trim());
        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.ASCII.GetBytes(providedHash),
                Encoding.ASCII.GetBytes(user.OtpHash)))
        {
            var attempts = await _users.IncrementOtpAttemptsAsync(user.Id);
            var left = Math.Max(0, MaxOtpAttempts - attempts);
            ModelState.AddModelError("", left > 0
                ? $"Incorrect code. {left} attempt(s) left."
                : "Too many incorrect attempts. Please log in again.");
            if (left == 0)
            {
                await _users.ClearOtpAsync(user.Id);
                HttpContext.Session.Remove(PendingOtpSessionKey);
                return RedirectToAction(nameof(Login));
            }
            ViewBag.MaskedEmail = MaskEmail(HttpContext.Session.GetString("PendingOtpEmail"));
            return View(model);
        }

        // Success — single-use code: clear and sign in.
        await _users.ClearOtpAsync(user.Id);
        await _users.UpdateLastLoginAsync(user.Id);
        HttpContext.Session.Remove(PendingOtpSessionKey);
        HttpContext.Session.Remove("PendingOtpEmail");
        HttpContext.Session.Remove("PendingOtpLastSent");

        await SignInAsync(user, company, state.RememberMe);
        return LocalRedirect(state.ReturnUrl);
    }

    [HttpPost("/otp/resend")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> OtpResend()
    {
        var state = LoadPendingOtp();
        if (state == null) return RedirectToAction(nameof(Login));

        // Rate-limit resend so the SMTP server isn't hammered.
        var lastSentRaw = HttpContext.Session.GetString("PendingOtpLastSent");
        if (DateTime.TryParse(lastSentRaw, out var lastSent)
            && DateTime.UtcNow - lastSent < OtpResendCooldown)
        {
            TempData["Error"] = $"Please wait {(int)(OtpResendCooldown - (DateTime.UtcNow - lastSent)).TotalSeconds}s before requesting another code.";
            return RedirectToAction(nameof(Otp));
        }

        var user = await _users.GetByIdAsync(state.UserId);
        var company = user != null ? await _companies.GetByIdAsync(state.CompanyId) : null;
        if (user == null || company == null)
        {
            HttpContext.Session.Remove(PendingOtpSessionKey);
            return RedirectToAction(nameof(Login));
        }

        var send = await IssueAndSendOtpAsync(user, company);
        TempData[send.Success ? "Success" : "Error"] =
            send.Success ? "A new code has been sent." : "Couldn't send OTP — " + send.ErrorMessage;
        return RedirectToAction(nameof(Otp));
    }

    private PendingOtpState? LoadPendingOtp()
    {
        var raw = HttpContext.Session.GetString(PendingOtpSessionKey);
        if (string.IsNullOrEmpty(raw)) return null;
        try { return System.Text.Json.JsonSerializer.Deserialize<PendingOtpState>(raw); }
        catch { return null; }
    }

    private async Task<EmailService.SendResult> IssueAndSendOtpAsync(MasterUser user, Company company)
    {
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        await _users.SetOtpAsync(user.Id, HashOtp(code), DateTime.UtcNow.Add(OtpLifetime));
        HttpContext.Session.SetString("PendingOtpEmail", user.Email);
        HttpContext.Session.SetString("PendingOtpLastSent", DateTime.UtcNow.ToString("o"));

        var subject = $"Your login code: {code}";
        var safeName = System.Net.WebUtility.HtmlEncode(user.FullName ?? "");
        var html = $@"
            <div style='font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:520px;margin:0 auto;color:#1f2937'>
                <p>Hi {safeName},</p>
                <p>Use this one-time code to sign in to <strong>{System.Net.WebUtility.HtmlEncode(company.Name)}</strong>:</p>
                <div style='font-size:28px;font-weight:800;letter-spacing:8px;background:#f3f4f6;border-radius:8px;padding:14px 18px;text-align:center;margin:14px 0'>{code}</div>
                <p style='color:#6b7280;font-size:13px'>
                    This code expires in {(int)OtpLifetime.TotalMinutes} minutes.
                    If you didn't try to sign in, you can safely ignore this email.
                </p>
            </div>";
        var result = await _email.SendAsync(company, user.Email, subject, html);
        if (!result.Success)
            _log.LogWarning("OTP email failed for user {UserId}: {Err}", user.Id, result.ErrorMessage);
        return result;
    }

    private static string HashOtp(string code)
    {
        // Short-lived secret — SHA256 over (UserId-independent) code is fine.
        // We never store the plaintext code, only the hash.
        Span<byte> hash = stackalloc byte[32];
        SHA256.HashData(Encoding.UTF8.GetBytes(code), hash);
        return Convert.ToHexString(hash);
    }

    private static string? MaskEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email)) return null;
        var at = email.IndexOf('@');
        if (at < 2) return email;
        var localVisible = Math.Min(2, at);
        return email[..localVisible] + new string('•', Math.Max(1, at - localVisible)) + email[at..];
    }

    [HttpGet("/register")]
    public IActionResult Register() =>
        User.Identity?.IsAuthenticated == true ? RedirectToAction("Index", "Dashboard") : View(new RegisterCompanyDto());

    [HttpPost("/register")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Register(RegisterCompanyDto model)
    {
        if (!ModelState.IsValid) return View(model);

        if (await _companies.ExistsAsync(model.Slug))
        {
            ModelState.AddModelError("Slug", "This company URL is already taken. Please choose another.");
            return View(model);
        }

        var existingUser = await _users.GetByEmailAsync(model.AdminEmail);
        if (existingUser != null)
        {
            ModelState.AddModelError("AdminEmail", "This email is already registered.");
            return View(model);
        }

        var dbName = await _companies.GenerateDbNameAsync();

        var company = new Company
        {
            Name = model.CompanyName,
            Slug = model.Slug,
            DatabaseName = dbName,
            Email = model.CompanyEmail,
            Phone = model.CompanyPhone,
            Country = model.Country,
            LicenseNumber = model.LicenseNumber ?? "",
            TrialEndsAt = DateTime.UtcNow.AddDays(30),
            CreatedAt = DateTime.UtcNow
        };

        var companyId = await _companies.InsertAsync(company);

        var adminUser = new MasterUser
        {
            CompanyId = companyId,
            FullName = model.AdminFullName,
            Email = model.AdminEmail,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(model.AdminPassword),
            Role = TravelERP.Shared.Enums.UserRole.CompanyAdmin,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        var adminUserId = await _users.InsertAsync(adminUser);

        try
        {
            var superAdminRoleId = await _provisioner.ProvisionAsync(dbName);
            await _users.SetTenantRoleAsync(adminUserId, superAdminRoleId);
        }
        catch (Exception ex)
        {
            TempData["ProvisionError"] = $"Database setup failed: {ex.Message}. Contact support.";
        }

        TempData["Reg_CompanyName"] = model.CompanyName;
        TempData["Reg_CompanyCode"] = model.Slug;
        TempData["Reg_AdminEmail"] = model.AdminEmail;
        TempData["Reg_AdminName"] = model.AdminFullName;
        return RedirectToAction(nameof(RegisterSuccess));
    }

    [HttpGet("/register/success")]
    public IActionResult RegisterSuccess()
    {
        if (TempData["Reg_CompanyCode"] == null) return RedirectToAction(nameof(Register));
        return View();
    }

    [HttpGet("/plans")]
    public async Task<IActionResult> Plans([FromServices] ISubscriptionPlanRepository plans)
    {
        var visible = (await plans.GetAllAsync(includeInactive: false)).ToList();
        return View(visible);
    }

    [HttpPost("/logout")]
    [Authorize]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }

    private async Task SignInAsync(MasterUser user, Company company, bool rememberMe)
    {
        var isPlatformAdmin = user.Role == TravelERP.Shared.Enums.UserRole.SuperAdmin;
        var isCompanyAdmin  = user.Role == TravelERP.Shared.Enums.UserRole.CompanyAdmin;

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.Role.ToString()),
            new("UserId", user.Id.ToString()),
            new("FullName", user.FullName),
            new("CompanyId", company.Id.ToString()),
            new("CompanyName", company.Name),
            new("CompanySlug", company.Slug),
            new("DatabaseName", company.DatabaseName),
            new("Currency", company.Currency),
            new("CurrencySymbol", company.CurrencySymbol),
        };

        if (isPlatformAdmin)
        {
            // Platform admin has no tenant — no IsSuperAdmin company claim, no tenant permissions.
            // Role claim "SuperAdmin" is what AdminController gates on.
        }
        else if (isCompanyAdmin)
        {
            claims.Add(new Claim("IsSuperAdmin", "true"));
        }
        else if (user.TenantRoleId.HasValue)
        {
            claims.Add(new Claim("TenantRoleId", user.TenantRoleId.Value.ToString()));
            // Load role — check if IsSystem (tenant SuperAdmin role) and OnlyAssigned scope
            using var conn = _dbFactory.CreateTenantConnection(company.DatabaseName);
            var role = await conn.QuerySingleOrDefaultAsync<(bool IsSystem, bool OnlyAssigned)>(
                "SELECT IsSystem, OnlyAssigned FROM Roles WHERE Id = @Id", new { Id = user.TenantRoleId.Value });
            if (role.IsSystem)
            {
                claims.Add(new Claim("IsSuperAdmin", "true"));
            }
            else
            {
                if (role.OnlyAssigned) claims.Add(new Claim("OnlyAssigned", "true"));

                var perms = await conn.QueryAsync<(string Module, bool CanView, bool CanAdd, bool CanEdit, bool CanDelete)>(
                    @"SELECT Module, CanView, CanAdd, CanEdit, CanDelete
                      FROM RolePermissions WHERE RoleId = @Id",
                    new { Id = user.TenantRoleId.Value });
                foreach (var p in perms)
                {
                    if (p.CanView)   claims.Add(new Claim("Perm", $"{p.Module}.View"));
                    if (p.CanAdd)    claims.Add(new Claim("Perm", $"{p.Module}.Add"));
                    if (p.CanEdit)   claims.Add(new Claim("Perm", $"{p.Module}.Edit"));
                    if (p.CanDelete) claims.Add(new Claim("Perm", $"{p.Module}.Delete"));
                }
            }
        }

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        var principal = new ClaimsPrincipal(identity);

        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal,
            new AuthenticationProperties
            {
                IsPersistent = rememberMe,
                ExpiresUtc = rememberMe ? DateTimeOffset.UtcNow.AddDays(30) : DateTimeOffset.UtcNow.AddHours(12)
            });
    }
}
