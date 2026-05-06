namespace TravelERP.Core.Entities.Tenant;

public class LeadStatus
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = "secondary";   // bootstrap variant
    public int DisplayOrder { get; set; }
    public bool IsDefault { get; set; }
    public bool IsClosed { get; set; }      // terminal status
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }
}
