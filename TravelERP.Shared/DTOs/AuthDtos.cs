using System.ComponentModel.DataAnnotations;

namespace TravelERP.Shared.DTOs;

public class LoginDto
{
    [Required, Display(Name = "Company Code")]
    public string CompanyCode { get; set; } = string.Empty;

    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;

    public bool RememberMe { get; set; }
}

public class RegisterCompanyDto
{
    [Required, MaxLength(150)]
    public string CompanyName { get; set; } = string.Empty;

    [Required, MaxLength(50), RegularExpression(@"^[a-z0-9\-]+$", ErrorMessage = "Slug can only contain lowercase letters, numbers and hyphens")]
    public string Slug { get; set; } = string.Empty;

    [Required, EmailAddress]
    public string CompanyEmail { get; set; } = string.Empty;

    [Required, Phone]
    public string CompanyPhone { get; set; } = string.Empty;

    [Required, MaxLength(150)]
    public string AdminFullName { get; set; } = string.Empty;

    [Required, EmailAddress]
    public string AdminEmail { get; set; } = string.Empty;

    [Required, MinLength(8)]
    public string AdminPassword { get; set; } = string.Empty;

    [Required, Compare("AdminPassword")]
    public string ConfirmPassword { get; set; } = string.Empty;

    [Required]
    public string Country { get; set; } = string.Empty;

    public string? LicenseNumber { get; set; }
}

public class OtpVerifyDto
{
    [Required, RegularExpression(@"^\d{6}$", ErrorMessage = "Enter the 6-digit code.")]
    public string Code { get; set; } = string.Empty;
}

public class ChangePasswordDto
{
    [Required]
    public string CurrentPassword { get; set; } = string.Empty;

    [Required, MinLength(8)]
    public string NewPassword { get; set; } = string.Empty;

    [Required, Compare("NewPassword")]
    public string ConfirmPassword { get; set; } = string.Empty;
}
