using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class VisaController : Controller
{
    private readonly IVisaRepository _repo;
    private readonly ICustomerRepository _customers;
    private readonly ITenantContext _tenant;

    public VisaController(IVisaRepository repo, ICustomerRepository customers, ITenantContext tenant)
    {
        _repo = repo;
        _customers = customers;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        ViewData["Title"] = "Visa & Documents";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Visa & Documents", null) };
        return View(await _repo.GetAllAsync());
    }

    public async Task<IActionResult> Details(int id)
    {
        var visa = await _repo.GetByIdAsync(id);
        if (visa == null) return NotFound();
        ViewData["Title"] = $"Visa — {visa.ApplicationNumber}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Visa", "/Visa"), (visa.ApplicationNumber, null) };
        return View(visa);
    }

    public async Task<IActionResult> Create()
    {
        ViewData["Title"] = "New Visa Application";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Visa", "/Visa"), ("New Application", null) };
        ViewBag.Customers = await _customers.GetAllAsync();
        return View(new VisaApplication { AppliedOn = DateTime.Today });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(VisaApplication model)
    {
        if (!ModelState.IsValid)
        {
            ViewBag.Customers = await _customers.GetAllAsync();
            return View(model);
        }

        var count = (await _repo.GetAllAsync()).Count();
        model.ApplicationNumber = $"VISA{DateTime.Now:yyMM}{(count + 1):D4}";
        model.HandledById = _tenant.UserId;
        model.CreatedBy = _tenant.UserId;
        model.CreatedAt = DateTime.UtcNow;
        await _repo.InsertAsync(model);

        TempData["Success"] = $"Visa application {model.ApplicationNumber} created.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateStatus(int id, int status, string? notes)
    {
        await _repo.UpdateStatusAsync(id, status, notes);
        TempData["Success"] = "Visa status updated.";
        return RedirectToAction(nameof(Details), new { id });
    }
}
