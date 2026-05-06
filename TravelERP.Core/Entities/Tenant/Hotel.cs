namespace TravelERP.Core.Entities.Tenant;

public class Hotel
{
    public int Id { get; set; }
    public int DestinationId { get; set; }
    public string Name { get; set; } = string.Empty;
    public byte Category { get; set; } = 3;   // 1..5 stars
    public string? ImageUrl { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    public string? DestinationName { get; set; }   // populated by joins
}
