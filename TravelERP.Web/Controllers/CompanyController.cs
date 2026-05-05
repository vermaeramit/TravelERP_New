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

    public CompanyController(ICompanyRepository companies, IUserRepository users, ITenantContext tenant)
    {
        _companies = companies;
        _users = users;
        _tenant = tenant;
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
}
