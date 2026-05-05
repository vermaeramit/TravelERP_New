using TravelERP.Shared.Enums;

namespace TravelERP.Core.Entities.Tenant;

public class VisaApplication : BaseEntity
{
    public string ApplicationNumber { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public int? BookingId { get; set; }
    public string VisaType { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public VisaStatus Status { get; set; } = VisaStatus.NotApplied;
    public DateTime? AppliedOn { get; set; }
    public DateTime? SubmittedOn { get; set; }
    public DateTime? ApprovedOn { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public string? RejectionReason { get; set; }
    public string? VisaNumber { get; set; }
    public string? Notes { get; set; }
    public int? HandledById { get; set; }
}

public class PassengerDocument : BaseEntity
{
    public int CustomerId { get; set; }
    public int? BookingId { get; set; }
    public DocumentType DocumentType { get; set; }
    public string DocumentNumber { get; set; } = string.Empty;
    public DateTime? IssueDate { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public string? IssuingCountry { get; set; }
    public string? FileUrl { get; set; }
    public string? Notes { get; set; }
}
