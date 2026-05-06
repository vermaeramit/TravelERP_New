using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class MailTemplatesController : Controller
{
    private readonly IMailTemplateRepository _repo;
    private readonly ITenantContext _tenant;

    public static readonly string[] Categories =
        ["Booking", "Invoice", "Payment", "Welcome", "Visa", "Itinerary", "Other"];

    public MailTemplatesController(IMailTemplateRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Mail Templates";
        return View(await _repo.GetAllAsync());
    }

    [HttpGet]
    public IActionResult Create()
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Add Mail Template";
        ViewBag.Categories = Categories;
        return View(new MailTemplate());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(MailTemplate model)
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        if (string.IsNullOrWhiteSpace(model.Name))
            ModelState.AddModelError(nameof(model.Name), "Template name is required.");
        if (string.IsNullOrWhiteSpace(model.Subject))
            ModelState.AddModelError(nameof(model.Subject), "Subject is required.");

        if (!ModelState.IsValid)
        {
            ViewData["Title"] = "Add Mail Template";
            ViewBag.Categories = Categories;
            return View(model);
        }

        await _repo.InsertAsync(model);
        TempData["Success"] = $"Mail template '{model.Name}' created.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        var t = await _repo.GetByIdAsync(id);
        if (t == null) return NotFound();
        ViewData["Title"] = $"Edit — {t.Name}";
        ViewBag.Categories = Categories;
        return View(t);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(MailTemplate model)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        if (string.IsNullOrWhiteSpace(model.Name))
            ModelState.AddModelError(nameof(model.Name), "Template name is required.");
        if (string.IsNullOrWhiteSpace(model.Subject))
            ModelState.AddModelError(nameof(model.Subject), "Subject is required.");

        if (!ModelState.IsValid)
        {
            ViewData["Title"] = $"Edit — {model.Name}";
            ViewBag.Categories = Categories;
            return View(model);
        }

        await _repo.UpdateAsync(model);
        TempData["Success"] = "Mail template updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Masters)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Mail template deactivated.";
        return RedirectToAction(nameof(Index));
    }
}
