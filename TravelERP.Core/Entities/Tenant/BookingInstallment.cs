namespace TravelERP.Core.Entities.Tenant;

public class BookingInstallment
{
    public int Id { get; set; }
    public int BookingId { get; set; }
    public int InstallmentNo { get; set; }
    public decimal Amount { get; set; }
    public string? PaymentMode { get; set; }     // Cash / UPI / NEFT / RTGS / Card / Cheque / Other
    public string PaymentStatus { get; set; } = "Pending";   // Pending / Received / Refunded
    public DateTime? DueDate { get; set; }
    public DateTime? ReceivedDate { get; set; }
    public string? Remark { get; set; }
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }
}
