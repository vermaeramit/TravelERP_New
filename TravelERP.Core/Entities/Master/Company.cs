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
    public string LeadPrefix { get; set; } = "LD";
    public string PackagePrefix { get; set; } = "PKG";
    public string BookingPrefix { get; set; } = "BK";
    public string InvoicePrefix { get; set; } = "INV";

    // SMTP / email-sending (per-tenant)
    public string? SmtpHost { get; set; }
    public int? SmtpPort { get; set; }
    public string? SmtpUsername { get; set; }
    public string? SmtpPassword { get; set; }
    public string? SmtpFromEmail { get; set; }
    public string? SmtpFromName { get; set; }
    public bool SmtpUseTls { get; set; } = true;

    // Voucher defaults — shown on every Hotel Voucher. Configurable per company.
    public string? VoucherCheckInTime  { get; set; }
    public string? VoucherCheckOutTime { get; set; }
    public string? VoucherHotelNote    { get; set; }
    public string? VoucherPolicyHtml   { get; set; }

    public bool IsSmtpConfigured =>
        !string.IsNullOrWhiteSpace(SmtpHost)
        && SmtpPort.HasValue
        && !string.IsNullOrWhiteSpace(SmtpFromEmail);

    // Public quote branding
    public string? GreetingParagraph { get; set; }
    public string? WhyBookWithUs { get; set; }   // JSON: [{"icon":"bi-headset","title":"24/7 Support"}, …]

    // Google Business reviews — shown at bottom of public quote page
    public string? GooglePlaceId { get; set; }
    public string? GoogleApiKey { get; set; }
    public string? GoogleReviewsCacheJson { get; set; }     // cached Places API response
    public DateTime? GoogleReviewsCachedAt { get; set; }    // UTC; service refreshes if > 12h

    // When true, /login requires a 6-digit OTP (emailed via per-tenant SMTP) after password.
    public bool RequireOtpLogin { get; set; }
}
