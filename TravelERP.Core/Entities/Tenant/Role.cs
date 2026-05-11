namespace TravelERP.Core.Entities.Tenant;

public class Role
{
    public int Id { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsSystem { get; set; }   // true = SuperAdmin, non-editable
    public bool IsActive { get; set; } = true;
    public bool OnlyAssigned { get; set; }   // true = users in this role only see leads/bookings assigned to them
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    public List<RolePermission> Permissions { get; set; } = [];
}
