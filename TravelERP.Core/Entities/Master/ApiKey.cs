namespace TravelERP.Core.Entities.Master;

public class ApiKey
{
    public int Id { get; set; }
    public int CompanyId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Key { get; set; } = string.Empty;     // mapped from ApiKey column
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int? CreatedBy { get; set; }
    public DateTime? LastUsedAt { get; set; }
    public DateTime? ExpiresAt { get; set; }

    // joined from Companies on lookup (only populated by GetByKey)
    public string? DatabaseName { get; set; }
    public byte? CompanyStatus { get; set; }
    public string? LeadPrefix { get; set; }
}
