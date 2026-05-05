using TravelERP.Shared.Enums;

namespace TravelERP.Core.Entities.Tenant;

public class Employee : BaseEntity
{
    public string EmployeeCode { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string FullName => $"{FirstName} {LastName}";
    public string Email { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public Gender Gender { get; set; }
    public DateTime DateOfBirth { get; set; }
    public string Designation { get; set; } = string.Empty;
    public string Department { get; set; } = string.Empty;
    public int? BranchId { get; set; }
    public DateTime JoiningDate { get; set; }
    public DateTime? LeavingDate { get; set; }
    public EmploymentStatus Status { get; set; } = EmploymentStatus.Active;
    public decimal BasicSalary { get; set; }
    public string? Address { get; set; }
    public string? EmergencyContact { get; set; }
    public string? ProfileImageUrl { get; set; }
    public int? MasterUserId { get; set; }
}
