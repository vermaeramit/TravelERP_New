namespace TravelERP.Core.Entities.Tenant;

public class PackageOptionHotel
{
    public int Id { get; set; }
    public int PackageOptionId { get; set; }
    public int DisplayOrder { get; set; }
    public int Nights { get; set; } = 1;
    public int? HotelId { get; set; }
    public int? RoomTypeId { get; set; }
    public int? MealPlanId { get; set; }
    public string? OtherText { get; set; }

    // Joined
    public string? HotelName { get; set; }
    public string? HotelImageUrl { get; set; }
    public byte? HotelCategory { get; set; }
    public string? RoomTypeName { get; set; }
    public string? MealPlanCode { get; set; }
    public string? MealPlanName { get; set; }
}
