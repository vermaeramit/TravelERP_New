namespace TravelERP.Core.Entities.Tenant;

public class Supplier : BaseEntity
{
    public string SupplierCode { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string ContactPerson { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string? AlternatePhone { get; set; }
    public string Address { get; set; } = string.Empty;
    public string City { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public string? Website { get; set; }
    public string? TaxNumber { get; set; }
    public string? BankDetails { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Notes { get; set; }
    public decimal? CreditLimit { get; set; }
    public int? CreditDays { get; set; }
}
