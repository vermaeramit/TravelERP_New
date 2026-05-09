namespace TravelERP.Core.Entities.Tenant;

public class EmailLog
{
    public int Id { get; set; }
    public string RelatedType { get; set; } = "";   // Package / Booking / Other
    public int? RelatedId { get; set; }
    public string ToEmail { get; set; } = "";
    public string? CcEmail { get; set; }
    public string Subject { get; set; } = "";
    public string? BodyPreview { get; set; }
    public string? AttachmentNames { get; set; }
    public string Status { get; set; } = "Sent";    // Sent / Failed
    public string? ErrorMessage { get; set; }
    public DateTime SentAt { get; set; }
    public int SentBy { get; set; }
}
