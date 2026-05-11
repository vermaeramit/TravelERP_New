namespace TravelERP.Core.Interfaces;

public interface ITenantContext
{
    int CompanyId { get; }
    string DatabaseName { get; }
    string CompanyName { get; }
    string Currency { get; }
    string CurrencySymbol { get; }
    int UserId { get; }
    string UserFullName { get; }
    string UserEmail { get; }
    string UserRole { get; }
    int? TenantRoleId { get; }
    bool IsSuperAdmin { get; }
    bool CanView(string module);
    bool CanAdd(string module);
    bool CanEdit(string module);
    bool CanDelete(string module);

    /// <summary>True when the user's role is restricted to assigned data only.</summary>
    bool OnlyAssigned { get; }
    /// <summary>UserId to filter by in queries (returns null when the user can see everything).</summary>
    int? ScopeUserId { get; }
}
