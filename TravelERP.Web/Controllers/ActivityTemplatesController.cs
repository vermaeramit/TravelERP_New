using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class ActivityTemplatesController : Controller
{
    private readonly IActivityTemplateRepository _repo;
    private readonly ITenantContext _tenant;

    public static readonly string[] TypeOptions =
        ["All", ActivityTypes.Call, ActivityTypes.Email, ActivityTypes.WhatsApp,
         ActivityTypes.Meeting, ActivityTypes.Note, ActivityTypes.FollowUp];

    public ActivityTemplatesController(IActivityTemplateRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Activity Templates";
        return View(await _repo.GetAllAsync());
    }

    [HttpGet]
    public IActionResult Create()
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Add Activity Template";
        ViewBag.Types = TypeOptions;
        return View(new ActivityTemplate());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(ActivityTemplate model)
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        Validate(model);
        if (!ModelState.IsValid)
        {
            ViewData["Title"] = "Add Activity Template";
            ViewBag.Types = TypeOptions;
            return View(model);
        }
        await _repo.InsertAsync(model);
        TempData["Success"] = $"Template '{model.Name}' created.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        var t = await _repo.GetByIdAsync(id);
        if (t == null) return NotFound();
        ViewData["Title"] = $"Edit — {t.Name}";
        ViewBag.Types = TypeOptions;
        return View(t);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(ActivityTemplate model)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        Validate(model);
        if (!ModelState.IsValid)
        {
            ViewData["Title"] = $"Edit — {model.Name}";
            ViewBag.Types = TypeOptions;
            return View(model);
        }
        await _repo.UpdateAsync(model);
        TempData["Success"] = "Template updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Masters)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Template deactivated.";
        return RedirectToAction(nameof(Index));
    }

    private void Validate(ActivityTemplate t)
    {
        if (string.IsNullOrWhiteSpace(t.Name))
            ModelState.AddModelError(nameof(t.Name), "Name is required.");
        if (string.IsNullOrWhiteSpace(t.ActivityType))
            t.ActivityType = "All";
    }
}
