using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Shared.Enums;

namespace TravelERP.Web.Controllers;

[Authorize]
[Route("[controller]")]
public class HRController : Controller
{
    private readonly IEmployeeRepository _repo;
    private readonly ITenantContext _tenant;

    public HRController(IEmployeeRepository repo, ITenantContext tenant)
    {
        _repo = repo;
        _tenant = tenant;
    }

    [HttpGet("Employees")]
    public async Task<IActionResult> Employees()
    {
        ViewData["Title"] = "Employees";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("HR", null), ("Employees", null) };
        return View(await _repo.GetAllAsync());
    }

    [HttpGet("Employee/{id}")]
    public async Task<IActionResult> EmployeeDetails(int id)
    {
        var emp = await _repo.GetByIdAsync(id);
        if (emp == null) return NotFound();
        ViewData["Title"] = emp.FullName;
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("HR", null), ("Employees", "/HR/Employees"), (emp.FullName, null) };
        ViewBag.Leaves = await _repo.GetLeavesByEmployeeAsync(id);
        return View(emp);
    }

    [HttpGet("Employee/Create")]
    public async Task<IActionResult> CreateEmployee()
    {
        ViewData["Title"] = "New Employee";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("HR", null), ("Employees", "/HR/Employees"), ("New Employee", null) };
        return View(new Employee { EmployeeCode = await _repo.GenerateEmployeeCodeAsync(), JoiningDate = DateTime.Today });
    }

    [HttpPost("Employee/Create")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateEmployee(Employee model)
    {
        if (!ModelState.IsValid) return View(model);
        model.CreatedBy = _tenant.UserId;
        model.CreatedAt = DateTime.UtcNow;
        await _repo.InsertAsync(model);
        TempData["Success"] = $"Employee {model.FullName} added.";
        return RedirectToAction(nameof(Employees));
    }

    [HttpGet("Employee/{id}/Edit")]
    public async Task<IActionResult> EditEmployee(int id)
    {
        var emp = await _repo.GetByIdAsync(id);
        if (emp == null) return NotFound();
        ViewData["Title"] = $"Edit — {emp.FullName}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("HR", null), ("Employees", "/HR/Employees"), ("Edit", null) };
        return View(emp);
    }

    [HttpPost("Employee/{id}/Edit")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditEmployee(int id, Employee model)
    {
        if (!ModelState.IsValid) return View(model);
        model.Id = id;
        model.UpdatedBy = _tenant.UserId;
        model.UpdatedAt = DateTime.UtcNow;
        await _repo.UpdateAsync(model);
        TempData["Success"] = "Employee updated.";
        return RedirectToAction(nameof(EmployeeDetails), new { id });
    }

    [HttpGet("Leaves")]
    public async Task<IActionResult> Leaves()
    {
        ViewData["Title"] = "Leave Management";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("HR", null), ("Leaves", null) };
        ViewBag.PendingLeaves = await _repo.GetPendingLeavesAsync();
        return View();
    }

    [HttpPost("Leave/{id}/Approve")]
    [Authorize(Roles = "SuperAdmin,CompanyAdmin,Manager,HRManager")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ApproveLeave(int id, string remarks)
    {
        await _repo.UpdateLeaveStatusAsync(id, (int)LeaveStatus.Approved, _tenant.UserId, remarks);
        TempData["Success"] = "Leave approved.";
        return RedirectToAction(nameof(Leaves));
    }

    [HttpPost("Leave/{id}/Reject")]
    [Authorize(Roles = "SuperAdmin,CompanyAdmin,Manager,HRManager")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RejectLeave(int id, string remarks)
    {
        await _repo.UpdateLeaveStatusAsync(id, (int)LeaveStatus.Rejected, _tenant.UserId, remarks);
        TempData["Success"] = "Leave rejected.";
        return RedirectToAction(nameof(Leaves));
    }
}
