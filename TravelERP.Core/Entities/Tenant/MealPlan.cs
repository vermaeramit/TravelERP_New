namespace TravelERP.Core.Entities.Tenant;

public class MealPlan
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;       // CP, MAP, AP, EP, AI
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }
}
