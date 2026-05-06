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
    public async Task<IActionResult> Create(Role model, Dictionary<string, bool[]> perms)
    {
        if (!_tenant.CanAdd(AppModules.Roles)) return Forbid();
        if (!ModelState.IsValid) { ViewBag.Modules = AppModules.All; return View(model); }

        var id = await _repo.InsertAsync(model);
        await SavePermissions(id, perms);

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
    public async Task<IActionResult> Edit(Role model, Dictionary<string, bool[]> perms)
    {
        if (!_tenant.CanEdit(AppModules.Roles)) return Forbid();
        if (!ModelState.IsValid) { ViewBag.Modules = AppModules.All; return View(model); }

        await _repo.UpdateAsync(model);
        await SavePermissions(model.Id, perms);

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

    private async Task SavePermissions(int roleId, Dictionary<string, bool[]> perms)
    {
        foreach (var module in AppModules.All)
        {
            if (perms.TryGetValue(module, out var bits) && bits.Length >= 4)
                await _repo.SavePermissionAsync(roleId, module, bits[0], bits[1], bits[2], bits[3]);
            else
                await _repo.SavePermissionAsync(roleId, module, false, false, false, false);
        }
    }
}
