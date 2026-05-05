using TravelERP.Shared.Enums;

namespace TravelERP.Core.Entities.Tenant;

public class Booking : BaseEntity
{
    public string BookingReference { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public int? PackageId { get; set; }
    public BookingType BookingType { get; set; }
    public BookingStatus Status { get; set; } = BookingStatus.Inquiry;
    public PaymentStatus PaymentStatus { get; set; } = PaymentStatus.Unpaid;
    public DateTime TravelDate { get; set; }
    public DateTime? ReturnDate { get; set; }
    public int Adults { get; set; } = 1;
    public int Children { get; set; } = 0;
    public int Infants { get; set; } = 0;
    public string Destination { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }
    public decimal PaidAmount { get; set; } = 0;
    public decimal DiscountAmount { get; set; } = 0;
    public string? SpecialRequests { get; set; }
    public string? InternalNotes { get; set; }
    public int? BranchId { get; set; }
    public int? AgentId { get; set; }

    public Customer? Customer { get; set; }
    public TourPackage? Package { get; set; }
}
