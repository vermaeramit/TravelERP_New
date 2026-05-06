namespace TravelERP.Core.Entities.Tenant;

public class ActivityTemplate
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string ActivityType { get; set; } = "All";   // All / Call / Email / WhatsApp / Meeting / Note / FollowUp
    public string? Subject { get; set; }
    public string? Notes { get; set; }
    public int DisplayOrder { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }
}
