using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class ItinerariesController : Controller
{
    private readonly IItineraryRepository _repo;
    private readonly IDestinationRepository _destinations;
    private readonly ITenantContext _tenant;

    public ItinerariesController(IItineraryRepository repo, IDestinationRepository destinations,
        ITenantContext tenant)
    {
        _repo = repo;
        _destinations = destinations;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Itineraries";
        return View(await _repo.GetAllAsync());
    }

    [HttpGet]
    public async Task<IActionResult> Create()
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Add Itinerary";
        ViewBag.Destinations = await _destinations.GetAllAsync();
        return View(new Itinerary());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Itinerary model)
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        if (model.DestinationId == 0)
            ModelState.AddModelError(nameof(model.DestinationId), "Destination is required.");
        if (string.IsNullOrWhiteSpace(model.Title))
            ModelState.AddModelError(nameof(model.Title), "Itinerary title is required.");

        if (!ModelState.IsValid)
        {
            ViewData["Title"] = "Add Itinerary";
            ViewBag.Destinations = await _destinations.GetAllAsync();
            return View(model);
        }

        await _repo.InsertAsync(model);
        TempData["Success"] = $"Itinerary '{model.Title}' created.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        var i = await _repo.GetByIdAsync(id);
        if (i == null) return NotFound();
        ViewData["Title"] = $"Edit — {i.Title}";
        ViewBag.Destinations = await _destinations.GetAllAsync();
        return View(i);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Itinerary model)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        var existing = await _repo.GetByIdAsync(model.Id);
        if (existing == null) return NotFound();

        if (model.DestinationId == 0)
            ModelState.AddModelError(nameof(model.DestinationId), "Destination is required.");
        if (string.IsNullOrWhiteSpace(model.Title))
            ModelState.AddModelError(nameof(model.Title), "Itinerary title is required.");

        if (!ModelState.IsValid)
        {
            ViewData["Title"] = $"Edit — {existing.Title}";
            ViewBag.Destinations = await _destinations.GetAllAsync();
            return View(model);
        }

        await _repo.UpdateAsync(model);
        TempData["Success"] = "Itinerary updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Masters)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Itinerary deactivated.";
        return RedirectToAction(nameof(Index));
    }
}
