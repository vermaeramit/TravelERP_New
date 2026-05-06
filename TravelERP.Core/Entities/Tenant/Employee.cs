namespace TravelERP.Core.Entities.Tenant;

public class Employee
{
    public int Id { get; set; }
    public int? UserId { get; set; }            // MasterUsers.Id (cross-DB, loose)
    public int? DesignationId { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string? LastName { get; set; }
    public string Email { get; set; } = string.Empty;       // CRM Login
    public string? Mobile { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? ImageUrl { get; set; }
    public string? ReplyEmail { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    public string? DesignationName { get; set; }   // join

    public string FullName => $"{FirstName} {LastName}".Trim();
}
