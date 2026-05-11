using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class MealPlansController : Controller
{
    private readonly IMealPlanRepository _repo;
    private readonly ITenantContext _tenant;

    public MealPlansController(IMealPlanRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.MealPlans)) return Forbid();
        ViewData["Title"] = "Meal Plans";
        return View(await _repo.GetAllAsync());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(string code, string name)
    {
        if (!_tenant.CanAdd(AppModules.MealPlans)) return Forbid();
        if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Code and Name are required.";
            return RedirectToAction(nameof(Index));
        }
        await _repo.InsertAsync(new MealPlan { Code = code.Trim().ToUpperInvariant(), Name = name.Trim() });
        TempData["Success"] = $"Meal plan '{code.Trim().ToUpperInvariant()}' added.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(int id, string code, string name)
    {
        if (!_tenant.CanEdit(AppModules.MealPlans)) return Forbid();
        if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Code and Name are required.";
            return RedirectToAction(nameof(Index));
        }
        await _repo.UpdateAsync(new MealPlan { Id = id, Code = code.Trim().ToUpperInvariant(), Name = name.Trim() });
        TempData["Success"] = "Meal plan updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.MealPlans)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Meal plan deactivated.";
        return RedirectToAction(nameof(Index));
    }
}
