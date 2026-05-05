namespace TravelERP.Core.Entities.Tenant;

public class Customer : BaseEntity
{
    public string CustomerCode { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string FullName => Name;
    public string Mobile { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? Destination { get; set; }
    public DateTime? TravelingDate { get; set; }
    public string? LeavingFrom { get; set; }
    public string? TravelCity { get; set; }
    public string? HotelRecommended { get; set; }
    public int? NoOfAdults { get; set; }
    public int? NoOfChildren { get; set; }
    public int? NoOfDays { get; set; }
    public string? AssignedTo { get; set; }
    public string? LeadSource { get; set; }
    public string? Infant { get; set; }
    public string? Remark { get; set; }
    // Kept from previous
    public string? PassportNumber { get; set; }
    public DateTime? PassportExpiry { get; set; }
    public string? Notes { get; set; }
}
