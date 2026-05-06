namespace TravelERP.Core.Entities.Tenant;

public class Lead
{
    public int Id { get; set; }
    public string LeadNumber { get; set; } = string.Empty;
    public int? StatusId { get; set; }
    public int? SourceId { get; set; }
    public int? AssignedToUserId { get; set; }
    public int? DestinationId { get; set; }

    public string Name { get; set; } = string.Empty;
    public string? Mobile { get; set; }
    public string? Email { get; set; }

    public DateTime? TravelingDate { get; set; }
    public string? LeavingFrom { get; set; }
    public string? HotelRecommended { get; set; }

    public int Adults { get; set; } = 1;
    public int Children { get; set; }
    public int Infants { get; set; }
    public int? Days { get; set; }

    public string? Remark { get; set; }

    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    // Joined fields (read-only)
    public string? StatusName { get; set; }
    public string? StatusColor { get; set; }
    public bool StatusIsClosed { get; set; }
    public string? SourceName { get; set; }
    public string? DestinationName { get; set; }

    // Populated by paged queries via COUNT(*) OVER() — identical on every row
    public int TotalCount { get; set; }

    public int TotalPax => Adults + Children + Infants;
}
