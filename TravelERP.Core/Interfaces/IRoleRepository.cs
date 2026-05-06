using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IRoleRepository
{
    Task<IEnumerable<Role>> GetAllAsync();
    Task<Role?> GetByIdAsync(int id);
    Task<IEnumerable<RolePermission>> GetPermissionsAsync(int roleId);
    Task<IEnumerable<RolePermission>> GetPermissionsForUserAsync(int tenantRoleId);
    Task<int> InsertAsync(Role role);
    Task UpdateAsync(Role role);
    Task SavePermissionAsync(int roleId, string module, bool canView, bool canAdd, bool canEdit, bool canDelete);
    Task DeleteAsync(int id);
}
