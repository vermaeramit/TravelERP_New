namespace TravelERP.Core.Entities.Tenant;

public class PackageDay
{
    public int Id { get; set; }
    public int PackageId { get; set; }
    public int DayNumber { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }

    public List<int> SightseeingIds { get; set; } = [];
    public List<string> SightseeingNames { get; set; } = [];   // populated on read for display
    public List<string> SightseeingImages { get; set; } = [];  // populated on read for display
}
