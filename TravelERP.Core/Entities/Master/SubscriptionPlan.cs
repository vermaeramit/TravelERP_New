namespace TravelERP.Core.Entities.Master;

public class SubscriptionPlan : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public decimal MonthlyPrice { get; set; }
    public decimal YearlyPrice { get; set; }
    public int MaxUsers { get; set; } = 5;
    public string? Features { get; set; }   // one feature per line; prefix '-' to render greyed-out
    public bool IsActive { get; set; } = true;

    // Marketing fields driving the public /plans page
    public string? Tagline { get; set; }
    public string? IconClass { get; set; }      // e.g. "bi-rocket-takeoff"
    public string? IconColor { get; set; }      // e.g. "#3b82f6"
    public bool IsFeatured { get; set; }        // "Most Popular" badge
    public int DisplayOrder { get; set; } = 100;
    public string? CtaLabel { get; set; }       // defaults to "Start Free Trial"
    public string? CtaUrl { get; set; }         // defaults to "/register"
}
