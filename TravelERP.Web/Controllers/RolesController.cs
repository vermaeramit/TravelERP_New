using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class RolesController : Controller
{
    private readonly IRoleRepository _repo;
    private readonly ITenantContext _tenant;

    public RolesController(IRoleRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Roles)) return Forbid();
        ViewData["Title"] = "Roles & Permissions";
        return View(await _repo.GetAllAsync());
    }

    [HttpGet]
    public IActionResult Create()
    {
        if (!_tenant.CanAdd(AppModules.Roles)) return Forbid();
        ViewData["Title"] = "New Role";
        ViewBag.Modules = AppModules.All;
        return View(new Role());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Role model)
    {
        if (!_tenant.CanAdd(AppModules.Roles)) return Forbid();
        if (!ModelState.IsValid) { ViewBag.Modules = AppModules.All; return View(model); }

        var id = await _repo.InsertAsync(model);
        await SavePermissions(id, Request.Form);

        TempData["Success"] = $"Role '{model.RoleName}' created successfully.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Roles)) return Forbid();
        var role = await _repo.GetByIdAsync(id);
        if (role == null) return NotFound();
        if (role.IsSystem)
        {
            TempData["Error"] = "SuperAdmin role cannot be edited.";
            return RedirectToAction(nameof(Index));
        }
        ViewData["Title"] = $"Edit Role — {role.RoleName}";
        ViewBag.Modules = AppModules.All;
        return View(role);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Role model)
    {
        if (!_tenant.CanEdit(AppModules.Roles)) return Forbid();
        if (!ModelState.IsValid) { ViewBag.Modules = AppModules.All; return View(model); }

        await _repo.UpdateAsync(model);
        await SavePermissions(model.Id, Request.Form);

        TempData["Success"] = "Role updated successfully.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Roles)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Role deactivated.";
        return RedirectToAction(nameof(Index));
    }

    /// <summary>
    /// Reads four flags per module out of the form: <c>View[Module]</c>, <c>Add[Module]</c>,
    /// <c>Edit[Module]</c>, <c>Delete[Module]</c>. Unchecked checkboxes don't post; we treat
    /// "absent" as false, "true" as true.
    /// </summary>
    private async Task SavePermissions(int roleId, Microsoft.AspNetCore.Http.IFormCollection form)
    {
        static bool Flag(Microsoft.AspNetCore.Http.IFormCollection f, string key) =>
            f.TryGetValue(key, out var v) && v.Any(x => string.Equals(x, "true", StringComparison.OrdinalIgnoreCase));

        foreach (var module in AppModules.All)
        {
            await _repo.SavePermissionAsync(
                roleId, module,
                canView:   Flag(form, $"View[{module}]"),
                canAdd:    Flag(form, $"Add[{module}]"),
                canEdit:   Flag(form, $"Edit[{module}]"),
                canDelete: Flag(form, $"Delete[{module}]"));
        }
    }
}
