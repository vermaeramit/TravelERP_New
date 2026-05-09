namespace TravelERP.Core.Entities.Tenant;

/// <summary>
/// Snapshot of one hotel row at booking time. Denormalized so the voucher
/// stays correct even if the source PackageOption is later edited or replaced.
/// </summary>
public class BookingHotel
{
    public int Id { get; set; }
    public int BookingId { get; set; }
    public int DisplayOrder { get; set; }
    public int Nights { get; set; } = 1;
    public string? HotelName { get; set; }
    public string? RoomTypeName { get; set; }
    public string? MealPlanCode { get; set; }
    public string? MealPlanName { get; set; }
    public string? OtherText { get; set; }
    public int Rooms { get; set; } = 1;
    public int ExtraBeds { get; set; }
    public string? HotelCnfNo { get; set; }
}
