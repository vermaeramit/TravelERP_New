using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
public class BankAccountsController : Controller
{
    private readonly IBankAccountRepository _repo;
    private readonly ITenantContext _tenant;

    public static readonly string[] AccountTypes = ["Savings", "Current", "OD"];

    public BankAccountsController(IBankAccountRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.BankAccounts)) return Forbid();
        ViewData["Title"] = "Bank Accounts";
        return View(await _repo.GetAllAsync());
    }

    [HttpGet]
    public IActionResult Create()
    {
        if (!_tenant.CanAdd(AppModules.BankAccounts)) return Forbid();
        ViewData["Title"] = "Add Bank Account";
        ViewBag.AccountTypes = AccountTypes;
        return View(new BankAccount());
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(BankAccount model)
    {
        if (!_tenant.CanAdd(AppModules.BankAccounts)) return Forbid();
        Validate(model);
        if (!ModelState.IsValid)
        {
            ViewData["Title"] = "Add Bank Account";
            ViewBag.AccountTypes = AccountTypes;
            return View(model);
        }
        await _repo.InsertAsync(model);
        TempData["Success"] = $"Bank account '{model.BankName}' added.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.BankAccounts)) return Forbid();
        var a = await _repo.GetByIdAsync(id);
        if (a == null) return NotFound();
        ViewData["Title"] = $"Edit — {a.BankName}";
        ViewBag.AccountTypes = AccountTypes;
        return View(a);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(BankAccount model)
    {
        if (!_tenant.CanEdit(AppModules.BankAccounts)) return Forbid();
        Validate(model);
        if (!ModelState.IsValid)
        {
            ViewData["Title"] = $"Edit — {model.BankName}";
            ViewBag.AccountTypes = AccountTypes;
            return View(model);
        }
        await _repo.UpdateAsync(model);
        TempData["Success"] = "Bank account updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.BankAccounts)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Bank account deactivated.";
        return RedirectToAction(nameof(Index));
    }

    private void Validate(BankAccount m)
    {
        if (string.IsNullOrWhiteSpace(m.BankName))
            ModelState.AddModelError(nameof(m.BankName), "Bank name is required.");
        if (string.IsNullOrWhiteSpace(m.HolderName))
            ModelState.AddModelError(nameof(m.HolderName), "Holder name is required.");
        if (string.IsNullOrWhiteSpace(m.AccountNumber))
            ModelState.AddModelError(nameof(m.AccountNumber), "Account number is required.");
    }
}
