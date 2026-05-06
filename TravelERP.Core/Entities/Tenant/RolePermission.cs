namespace TravelERP.Core.Entities.Tenant;

public class RolePermission
{
    public int Id { get; set; }
    public int RoleId { get; set; }
    public string Module { get; set; } = string.Empty;
    public bool CanView { get; set; }
    public bool CanAdd { get; set; }
    public bool CanEdit { get; set; }
    public bool CanDelete { get; set; }
}
