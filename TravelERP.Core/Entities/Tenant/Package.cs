namespace TravelERP.Core.Entities.Tenant;

public class Package
{
    public int Id { get; set; }
    public string PackageNumber { get; set; } = string.Empty;
    public int? LeadId { get; set; }
    public string Title { get; set; } = string.Empty;
    public int? DestinationId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string? CustomerMobile { get; set; }
    public string? CustomerEmail { get; set; }
    public int Adults { get; set; } = 1;
    public int Children { get; set; }
    public int Infants { get; set; }
    public int? Days { get; set; }
    public int? Nights { get; set; }
    public DateTime? StartDate { get; set; }
    public string PriceMode { get; set; } = "Total";   // Total / PerPax
    public string Currency { get; set; } = "INR";
    public string? FlightDetails { get; set; }
    public string? Inclusions { get; set; }
    public string? Exclusions { get; set; }
    public string? Notes { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    // Joined / aggregated
    public string? DestinationName { get; set; }
    public int OptionCount { get; set; }
    public decimal? MinPrice { get; set; }
    public decimal? MaxPrice { get; set; }
    public int TotalCount { get; set; }   // for paged lists

    public List<PackageOption> Options { get; set; } = [];
    public List<PackageDay> ItineraryDays { get; set; } = [];

    public int TotalPax => Adults + Children + Infants;
}
