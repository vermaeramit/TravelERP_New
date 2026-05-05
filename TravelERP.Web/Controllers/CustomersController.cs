using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class CustomersController : Controller
{
    private readonly ICustomerRepository _repo;
    private readonly ITenantContext _tenant;

    public CustomersController(ICustomerRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        ViewData["Title"] = "Customers";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Customers", null) };
        var customers = await _repo.GetAllAsync();
        return View(customers);
    }

    public async Task<IActionResult> Details(int id)
    {
        var customer = await _repo.GetByIdAsync(id);
        if (customer == null) return NotFound();
        ViewData["Title"] = customer.FullName;
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Customers", "/Customers"), (customer.FullName, null) };
        return View(customer);
    }

    public async Task<IActionResult> Create()
    {
        ViewData["Title"] = "New Customer";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Customers", "/Customers"), ("New Customer", null) };
        var model = new Customer { CustomerCode = await _repo.GenerateCustomerCodeAsync() };
        return View(model);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Customer model)
    {
        if (!ModelState.IsValid) return View(model);

        model.CreatedBy = _tenant.UserId;
        model.CreatedAt = DateTime.UtcNow;
        await _repo.InsertAsync(model);

        TempData["Success"] = $"Customer {model.Name} created successfully.";
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(int id)
    {
        var customer = await _repo.GetByIdAsync(id);
        if (customer == null) return NotFound();
        ViewData["Title"] = $"Edit — {customer.FullName}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Customers", "/Customers"), ("Edit", null) };
        return View(customer);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Customer model)
    {
        if (!ModelState.IsValid) return View(model);

        model.UpdatedBy = _tenant.UserId;
        model.UpdatedAt = DateTime.UtcNow;
        await _repo.UpdateAsync(model);

        TempData["Success"] = "Customer updated successfully.";
        return RedirectToAction(nameof(Details), new { id = model.Id });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Customer deleted.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Search(string q)
    {
        var results = await _repo.SearchAsync(q ?? "");
        return Json(results.Select(c => new { c.Id, name = c.Name, c.Mobile, c.Email, c.CustomerCode }));
    }
}
