using TravelERP.Shared.Enums;

namespace TravelERP.Core.Entities.Master;

public class Company : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public string DatabaseName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public string City { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public string LogoUrl { get; set; } = string.Empty;
    public string LicenseNumber { get; set; } = string.Empty;
    public string TaxNumber { get; set; } = string.Empty;
    public CompanyStatus Status { get; set; } = CompanyStatus.Trial;
    public DateTime TrialEndsAt { get; set; }
    public DateTime? SubscriptionEndsAt { get; set; }
    public string PlanName { get; set; } = "Trial";
    public int MaxUsers { get; set; } = 5;
    public string TimeZone { get; set; } = "UTC";
    public string Currency { get; set; } = "INR";
    public string CurrencySymbol { get; set; } = "₹";
}
