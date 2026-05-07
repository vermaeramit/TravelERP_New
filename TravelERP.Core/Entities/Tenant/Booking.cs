namespace TravelERP.Core.Entities.Tenant;

public class Booking
{
    public int Id { get; set; }
    public string BookingNumber { get; set; } = string.Empty;
    public string InvoiceNumber { get; set; } = string.Empty;
    public int? LeadId { get; set; }
    public int? PackageId { get; set; }
    public int? PackageOptionId { get; set; }
    public string? OptionName { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string? CustomerMobile { get; set; }
    public string? CustomerEmail { get; set; }
    public int Adults { get; set; } = 1;
    public int Children { get; set; }
    public int Infants { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int? Days { get; set; }
    public int? Nights { get; set; }
    public int? DestinationId { get; set; }
    public decimal TotalAmount { get; set; }
    public string Currency { get; set; } = "INR";
    public string Status { get; set; } = "Confirmed";   // Confirmed / Cancelled / Completed
    public string? Notes { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    // Joined / aggregated
    public string? DestinationName { get; set; }
    public string? DestinationTerms { get; set; }   // pulled from Destination.PackageTerms — shown on invoice
    public string? LeadNumber { get; set; }         // source lead number, joined for display
    public string? PackageNumber { get; set; }      // source quote/trip id, for invoice header
    public int InstallmentCount { get; set; }
    public decimal PaidAmount { get; set; }
    public int TotalCount { get; set; }   // for paged lists

    public List<BookingInstallment> Installments { get; set; } = [];

    public int TotalPax => Adults + Children + Infants;
    public decimal BalanceAmount => TotalAmount - PaidAmount;
}
