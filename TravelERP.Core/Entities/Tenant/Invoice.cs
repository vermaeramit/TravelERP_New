using TravelERP.Shared.Enums;

namespace TravelERP.Core.Entities.Tenant;

public class Invoice : BaseEntity
{
    public string InvoiceNumber { get; set; } = string.Empty;
    public int BookingId { get; set; }
    public int CustomerId { get; set; }
    public InvoiceStatus Status { get; set; } = InvoiceStatus.Draft;
    public DateTime InvoiceDate { get; set; }
    public DateTime DueDate { get; set; }
    public decimal SubTotal { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal PaidAmount { get; set; } = 0;
    public string? Notes { get; set; }
    public string? TermsAndConditions { get; set; }
}

public class Payment : BaseEntity
{
    public int InvoiceId { get; set; }
    public int CustomerId { get; set; }
    public int BookingId { get; set; }
    public decimal Amount { get; set; }
    public PaymentMethod Method { get; set; }
    public DateTime PaymentDate { get; set; }
    public string? ReferenceNumber { get; set; }
    public string? Notes { get; set; }
    public string ReceivedBy { get; set; } = string.Empty;
}
