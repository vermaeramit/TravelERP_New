namespace TravelERP.Core.Entities.Tenant;

public class BankAccount
{
    public int Id { get; set; }
    public string BankName { get; set; } = string.Empty;
    public string HolderName { get; set; } = string.Empty;
    public string AccountNumber { get; set; } = string.Empty;
    public string? IfscCode { get; set; }
    public string? Branch { get; set; }
    public string? AccountType { get; set; }   // Savings / Current / OD
    public string? UpiId { get; set; }
    public bool IsDefault { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public int CreatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }

    public string MaskedAccount =>
        AccountNumber.Length > 4
            ? new string('•', Math.Max(0, AccountNumber.Length - 4)) + AccountNumber[^4..]
            : AccountNumber;
}
