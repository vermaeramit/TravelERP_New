using TravelERP.Shared.Enums;

namespace TravelERP.Core.Entities.Tenant;

public class TourPackage : BaseEntity
{
    public string PackageCode { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public PackageType Type { get; set; }
    public PackageStatus Status { get; set; } = PackageStatus.Active;
    public string Destination { get; set; } = string.Empty;
    public string? Origin { get; set; }
    public int DurationDays { get; set; }
    public int DurationNights { get; set; }
    public decimal BasePrice { get; set; }
    public decimal? ChildPrice { get; set; }
    public decimal? InfantPrice { get; set; }
    public string? Inclusions { get; set; }
    public string? Exclusions { get; set; }
    public string? Itinerary { get; set; }
    public string? ImageUrl { get; set; }
    public int MaxCapacity { get; set; }
    public DateTime? ValidFrom { get; set; }
    public DateTime? ValidTo { get; set; }
    public bool IsFeatured { get; set; } = false;
}
