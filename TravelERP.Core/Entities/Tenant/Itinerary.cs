namespace TravelERP.Core.Entities.Tenant;

public class Itinerary
{
    public int Id { get; set; }
    public int DestinationId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    public string? DestinationName { get; set; }
}
