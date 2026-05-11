using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class RoomTypesController : Controller
{
    private readonly IRoomTypeRepository _repo;
    private readonly ITenantContext _tenant;

    public RoomTypesController(IRoomTypeRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.RoomTypes)) return Forbid();
        ViewData["Title"] = "Room Types";
        return View(await _repo.GetAllAsync());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(string name)
    {
        if (!_tenant.CanAdd(AppModules.RoomTypes)) return Forbid();
        if (string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Room type name is required.";
            return RedirectToAction(nameof(Index));
        }

        await _repo.InsertAsync(new RoomType { Name = name.Trim() });
        TempData["Success"] = $"Room type '{name.Trim()}' added.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(int id, string name)
    {
        if (!_tenant.CanEdit(AppModules.RoomTypes)) return Forbid();
        if (string.IsNullOrWhiteSpace(name))
        {
            TempData["Error"] = "Room type name is required.";
            return RedirectToAction(nameof(Index));
        }

        await _repo.UpdateAsync(new RoomType { Id = id, Name = name.Trim() });
        TempData["Success"] = "Room type updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.RoomTypes)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Room type deactivated.";
        return RedirectToAction(nameof(Index));
    }
}
