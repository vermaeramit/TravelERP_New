namespace TravelERP.Core.Entities.Tenant;

public class PackageOption
{
    public int Id { get; set; }
    public int PackageId { get; set; }
    public string OptionName { get; set; } = string.Empty;
    public int DisplayOrder { get; set; }
    public decimal LandPrice { get; set; }
    public decimal FlightPrice { get; set; }
    public decimal FinalPrice { get; set; }
    public bool IsRecommended { get; set; }
    public string? Notes { get; set; }

    public List<PackageOptionHotel> Hotels { get; set; } = [];
}
