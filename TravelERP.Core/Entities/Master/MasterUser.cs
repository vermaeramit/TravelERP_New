using TravelERP.Shared.Enums;

namespace TravelERP.Core.Entities.Master;

public class MasterUser : BaseEntity
{
    public int CompanyId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public UserRole Role { get; set; } = UserRole.Agent;
    public bool IsActive { get; set; } = true;
    public DateTime? LastLoginAt { get; set; }
    public string? ProfileImageUrl { get; set; }
    public int? TenantRoleId { get; set; }

    // Profile fields absorbed from the deprecated Employees module.
    public string? Mobile { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? ReplyEmail { get; set; }

    // OTP state. Loaded with the user so AuthController can verify without an extra round-trip.
    public string?   OtpHash { get; set; }
    public DateTime? OtpExpiresAt { get; set; }
    public DateTime? OtpIssuedAt { get; set; }
    public int       OtpAttempts { get; set; }
}
