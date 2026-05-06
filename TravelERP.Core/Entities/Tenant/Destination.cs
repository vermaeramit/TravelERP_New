namespace TravelERP.Core.Entities.Tenant;

public class Destination
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }
    public string? PackageTerms { get; set; }
    public string? InvoiceTerms { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    public List<DestinationReview> Reviews { get; set; } = [];
}
