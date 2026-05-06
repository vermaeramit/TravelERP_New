namespace TravelERP.Core.Entities.Tenant;

public class DestinationReview
{
    public int Id { get; set; }
    public int DestinationId { get; set; }
    public string TravelerName { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }
    public string? ReviewText { get; set; }
    public int DisplayOrder { get; set; }
}
