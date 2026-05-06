using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Shared.Enums;

namespace TravelERP.Web.Controllers;

[Authorize]
public class EmployeesController : Controller
{
    private readonly IEmployeeRepository _repo;
    private readonly IDesignationRepository _designations;
    private readonly IRoleRepository _roles;
    private readonly IUserRepository _users;
    private readonly ITenantContext _tenant;
    private readonly IWebHostEnvironment _env;

    private static readonly string[] AllowedExt = [".jpg", ".jpeg", ".png", ".webp", ".gif"];
    private const long MaxImageBytes = 5 * 1024 * 1024;

    public EmployeesController(IEmployeeRepository repo,
        IDesignationRepository designations, IRoleRepository roles, IUserRepository users,
        ITenantContext tenant, IWebHostEnvironment env)
    {
        _repo = repo;
        _designations = designations;
        _roles = roles;
        _users = users;
        _tenant = tenant;
        _env = env;
    }

    public async Task<IActionResult> Index()
    {
        if (!_tenant.CanView(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Employees";
        return View(await _repo.GetAllAsync());
    }

    [HttpGet]
    public async Task<IActionResult> Create()
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        ViewData["Title"] = "Add Employee";
        await PopulateLookupsAsync();
        return View(new EmployeeFormVm());
    }

    [HttpPost, ValidateAntiForgeryToken]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> Create(EmployeeFormVm model, IFormFile? photo)
    {
        if (!_tenant.CanAdd(AppModules.Masters)) return Forbid();
        Validate(model, isCreate: true);
        if (!ModelState.IsValid)
        {
            ViewData["Title"] = "Add Employee";
            await PopulateLookupsAsync();
            return View(model);
        }

        if (await _users.GetByEmailAsync(model.Email!) != null)
        {
            ModelState.AddModelError(nameof(model.Email), "This email is already registered.");
            ViewData["Title"] = "Add Employee";
            await PopulateLookupsAsync();
            return View(model);
        }

        var imageUrl = await SaveImageAsync(photo);

        // 1. Create master login user
        var user = new MasterUser
        {
            CompanyId       = _tenant.CompanyId,
            FullName        = $"{model.FirstName} {model.LastName}".Trim(),
            Email           = model.Email!.Trim().ToLowerInvariant(),
            PasswordHash    = BCrypt.Net.BCrypt.HashPassword(model.Password),
            Role            = UserRole.Agent,
            IsActive        = true,
            ProfileImageUrl = imageUrl,
            CreatedAt       = DateTime.UtcNow
        };
        var newUserId = await _users.InsertAsync(user);
        if (model.TenantRoleId.HasValue)
            await _users.SetTenantRoleAsync(newUserId, model.TenantRoleId.Value);

        // 2. Create employee record
        var emp = new Employee
        {
            UserId        = newUserId,
            DesignationId = model.DesignationId,
            FirstName     = model.FirstName!,
            LastName      = model.LastName,
            Email         = model.Email!.Trim().ToLowerInvariant(),
            Mobile        = model.Mobile,
            DateOfBirth   = model.DateOfBirth,
            ImageUrl      = imageUrl,
            ReplyEmail    = model.ReplyEmail
        };
        await _repo.InsertAsync(emp);

        TempData["Success"] = $"Employee '{emp.FullName}' created.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        var emp = await _repo.GetByIdAsync(id);
        if (emp == null) return NotFound();

        var vm = new EmployeeFormVm
        {
            Id            = emp.Id,
            DesignationId = emp.DesignationId,
            FirstName     = emp.FirstName,
            LastName      = emp.LastName,
            Email         = emp.Email,
            Mobile        = emp.Mobile,
            DateOfBirth   = emp.DateOfBirth,
            ReplyEmail    = emp.ReplyEmail,
            ImageUrl      = emp.ImageUrl,
            UserId        = emp.UserId
        };

        if (emp.UserId.HasValue)
        {
            var user = await _users.GetByIdAsync(emp.UserId.Value);
            vm.TenantRoleId = user?.TenantRoleId;
        }

        ViewData["Title"] = $"Edit — {emp.FullName}";
        await PopulateLookupsAsync();
        return View(vm);
    }

    [HttpPost, ValidateAntiForgeryToken]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> Edit(EmployeeFormVm model, IFormFile? photo)
    {
        if (!_tenant.CanEdit(AppModules.Masters)) return Forbid();
        var existing = await _repo.GetByIdAsync(model.Id);
        if (existing == null) return NotFound();

        Validate(model, isCreate: false);
        if (!ModelState.IsValid)
        {
            ViewData["Title"] = $"Edit — {existing.FullName}";
            await PopulateLookupsAsync();
            model.ImageUrl = existing.ImageUrl;
            return View(model);
        }

        var newImage = await SaveImageAsync(photo);
        var imageUrl = newImage ?? existing.ImageUrl;

        // 1. Update employee record
        var emp = new Employee
        {
            Id            = model.Id,
            UserId        = existing.UserId,
            DesignationId = model.DesignationId,
            FirstName     = model.FirstName!,
            LastName      = model.LastName,
            Email         = model.Email!.Trim().ToLowerInvariant(),
            Mobile        = model.Mobile,
            DateOfBirth   = model.DateOfBirth,
            ImageUrl      = imageUrl,
            ReplyEmail    = model.ReplyEmail
        };
        await _repo.UpdateAsync(emp);

        // 2. Update master user if linked
        if (existing.UserId.HasValue)
        {
            var user = await _users.GetByIdAsync(existing.UserId.Value);
            if (user != null)
            {
                user.FullName        = emp.FullName;
                user.Email           = emp.Email;
                user.ProfileImageUrl = imageUrl;
                await _users.UpdateAsync(user);
                if (model.TenantRoleId.HasValue)
                    await _users.SetTenantRoleAsync(user.Id, model.TenantRoleId.Value);
                if (!string.IsNullOrWhiteSpace(model.Password))
                    await _users.ChangePasswordAsync(user.Id, BCrypt.Net.BCrypt.HashPassword(model.Password));
            }
        }

        TempData["Success"] = "Employee updated.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Masters)) return Forbid();
        var emp = await _repo.GetByIdAsync(id);
        if (emp == null) return NotFound();

        await _repo.DeleteAsync(id);

        // Deactivate linked login as well
        if (emp.UserId.HasValue)
        {
            var user = await _users.GetByIdAsync(emp.UserId.Value);
            if (user != null)
            {
                user.IsActive = false;
                await _users.UpdateAsync(user);
            }
        }

        TempData["Success"] = "Employee deactivated.";
        return RedirectToAction(nameof(Index));
    }

    // ───────────────────────── helpers ─────────────────────────

    private void Validate(EmployeeFormVm model, bool isCreate)
    {
        if (string.IsNullOrWhiteSpace(model.FirstName))
            ModelState.AddModelError(nameof(model.FirstName), "First name is required.");
        if (string.IsNullOrWhiteSpace(model.Email))
            ModelState.AddModelError(nameof(model.Email), "Email is required.");
        if (isCreate && string.IsNullOrWhiteSpace(model.Password))
            ModelState.AddModelError(nameof(model.Password), "Password is required.");
        if (!string.IsNullOrEmpty(model.Password) && model.Password.Length < 6)
            ModelState.AddModelError(nameof(model.Password), "Password must be at least 6 characters.");
    }

    private async Task PopulateLookupsAsync()
    {
        ViewBag.Designations = await _designations.GetAllAsync();
        ViewBag.Roles        = await _roles.GetAllAsync();
    }

    private async Task<string?> SaveImageAsync(IFormFile? file)
    {
        if (file == null || file.Length == 0) return null;
        if (file.Length > MaxImageBytes) return null;
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExt.Contains(ext)) return null;

        var folder = Path.Combine(_env.WebRootPath, "uploads", "employees");
        Directory.CreateDirectory(folder);
        var fileName = $"{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(folder, fileName);
        await using var fs = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(fs);
        return $"/uploads/employees/{fileName}";
    }

    public class EmployeeFormVm
    {
        public int Id { get; set; }
        public int? UserId { get; set; }
        public int? DesignationId { get; set; }
        public int? TenantRoleId { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? Email { get; set; }
        public string? Password { get; set; }
        public string? Mobile { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? ReplyEmail { get; set; }
        public string? ImageUrl { get; set; }
    }
}
