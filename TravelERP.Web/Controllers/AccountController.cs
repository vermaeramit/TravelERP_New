using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Interfaces;

namespace TravelERP.Web.Controllers;

[Authorize]
[Route("[controller]")]
public class AccountController : Controller
{
    private readonly IUserRepository _users;
    private readonly ITenantContext _tenant;
    private readonly IWebHostEnvironment _env;

    private static readonly string[] AllowedPhotoExt = [".jpg", ".jpeg", ".png", ".webp", ".gif"];
    private const long MaxPhotoBytes = 5 * 1024 * 1024;

    public AccountController(IUserRepository users, ITenantContext tenant, IWebHostEnvironment env)
    {
        _users = users;
        _tenant = tenant;
        _env = env;
    }

    [HttpGet("Profile")]
    public async Task<IActionResult> Profile()
    {
        var user = await _users.GetByIdAsync(_tenant.UserId);
        if (user == null) return Forbid();
        ViewData["Title"] = "My Profile";
        return View(new ProfileVm
        {
            FullName    = user.FullName,
            Email       = user.Email,
            Mobile      = user.Mobile,
            DateOfBirth = user.DateOfBirth,
            ReplyEmail  = user.ReplyEmail,
            ImageUrl    = user.ProfileImageUrl
        });
    }

    [HttpPost("Profile"), ValidateAntiForgeryToken]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> Profile(ProfileVm vm, IFormFile? photo)
    {
        var user = await _users.GetByIdAsync(_tenant.UserId);
        if (user == null) return Forbid();

        if (string.IsNullOrWhiteSpace(vm.FullName))
            ModelState.AddModelError(nameof(vm.FullName), "Full name is required.");
        if (!ModelState.IsValid) { vm.ImageUrl = user.ProfileImageUrl; return View(vm); }

        var newImage = await SavePhotoAsync(photo);

        user.FullName    = vm.FullName.Trim();
        user.Mobile      = string.IsNullOrWhiteSpace(vm.Mobile) ? null : vm.Mobile.Trim();
        user.DateOfBirth = vm.DateOfBirth;
        user.ReplyEmail  = string.IsNullOrWhiteSpace(vm.ReplyEmail) ? null : vm.ReplyEmail.Trim();
        if (newImage != null) user.ProfileImageUrl = newImage;
        user.UpdatedAt = DateTime.UtcNow;
        user.UpdatedBy = _tenant.UserId;
        await _users.UpdateAsync(user);

        TempData["Success"] = "Profile updated.";
        return RedirectToAction(nameof(Profile));
    }

    [HttpGet("ChangePassword")]
    public IActionResult ChangePassword()
    {
        ViewData["Title"] = "Change Password";
        return View(new ChangePasswordVm());
    }

    [HttpPost("ChangePassword"), ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangePassword(ChangePasswordVm vm)
    {
        var user = await _users.GetByIdAsync(_tenant.UserId);
        if (user == null) return Forbid();

        if (string.IsNullOrWhiteSpace(vm.CurrentPassword)
            || !BCrypt.Net.BCrypt.Verify(vm.CurrentPassword, user.PasswordHash))
            ModelState.AddModelError(nameof(vm.CurrentPassword), "Current password is incorrect.");

        if (string.IsNullOrWhiteSpace(vm.NewPassword) || vm.NewPassword.Length < 6)
            ModelState.AddModelError(nameof(vm.NewPassword), "New password must be at least 6 characters.");

        if (vm.NewPassword != vm.ConfirmPassword)
            ModelState.AddModelError(nameof(vm.ConfirmPassword), "Passwords don't match.");

        if (!ModelState.IsValid) return View(vm);

        await _users.ChangePasswordAsync(user.Id, BCrypt.Net.BCrypt.HashPassword(vm.NewPassword));
        TempData["Success"] = "Password changed. Use the new password next time you sign in.";
        return RedirectToAction(nameof(Profile));
    }

    private async Task<string?> SavePhotoAsync(IFormFile? file)
    {
        if (file == null || file.Length == 0 || file.Length > MaxPhotoBytes) return null;
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedPhotoExt.Contains(ext)) return null;

        var folder = Path.Combine(_env.WebRootPath, "uploads", "users");
        Directory.CreateDirectory(folder);
        var fileName = $"u-{_tenant.UserId}-{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(folder, fileName);
        await using var fs = new FileStream(fullPath, FileMode.Create);
        await file.CopyToAsync(fs);
        return $"/uploads/users/{fileName}";
    }

    public class ProfileVm
    {
        public string FullName    { get; set; } = "";
        public string Email       { get; set; } = "";       // read-only — changing email = re-auth scenario
        public string? Mobile     { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? ReplyEmail { get; set; }
        public string? ImageUrl   { get; set; }
    }

    public class ChangePasswordVm
    {
        public string CurrentPassword { get; set; } = "";
        public string NewPassword     { get; set; } = "";
        public string ConfirmPassword { get; set; } = "";
    }
}
