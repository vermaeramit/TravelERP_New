using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Interfaces;
using TravelERP.Shared.DTOs;
using TravelERP.Web.Services;

namespace TravelERP.Web.Controllers;

[AllowAnonymous]
public class AuthController : Controller
{
    private readonly IUserRepository _users;
    private readonly ICompanyRepository _companies;
    private readonly TenantDbProvisioningService _provisioner;

    public AuthController(IUserRepository users, ICompanyRepository companies,
        TenantDbProvisioningService provisioner)
    {
        _users = users;
        _companies = companies;
        _provisioner = provisioner;
    }

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

        await _users.UpdateLastLoginAsync(user.Id);
        await SignInAsync(user, company, model.RememberMe);

        return LocalRedirect(string.IsNullOrEmpty(returnUrl) ? "/Dashboard" : returnUrl);
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

        await _users.InsertAsync(adminUser);

        try
        {
            await _provisioner.ProvisionAsync(dbName);
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
    public IActionResult Plans() => View();

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
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.Role.ToString()),
            new("UserId", user.Id.ToString()),
            new("FullName", user.FullName),
            new("CompanyId", company.Id.ToString()),
            new("CompanyName", company.Name),
            new("DatabaseName", company.DatabaseName),
            new("Currency", company.Currency),
            new("CurrencySymbol", company.CurrencySymbol),
        };

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
