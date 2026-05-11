using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class RoleRepository : IRoleRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public RoleRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<Role>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Role>(
            "sp_Role_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Role?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        var role = await conn.QuerySingleOrDefaultAsync<Role>(
            "sp_Role_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
        if (role != null)
            role.Permissions = (await GetPermissionsAsync(id)).ToList();
        return role;
    }

    public async Task<IEnumerable<RolePermission>> GetPermissionsAsync(int roleId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<RolePermission>(
            "sp_RolePermission_GetByRole",
            new { DatabaseName = _tenant.DatabaseName, RoleId = roleId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<RolePermission>> GetPermissionsForUserAsync(int tenantRoleId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<RolePermission>(
            "sp_RolePermission_GetByRole",
            new { DatabaseName = _tenant.DatabaseName, RoleId = tenantRoleId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Role role)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("RoleName",     role.RoleName);
        p.Add("Description",  role.Description);
        p.Add("IsSystem",     role.IsSystem);
        p.Add("OnlyAssigned", role.OnlyAssigned);
        p.Add("CreatedBy",    _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Role_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(Role role)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("Id",           role.Id);
        p.Add("RoleName",     role.RoleName);
        p.Add("Description",  role.Description);
        p.Add("OnlyAssigned", role.OnlyAssigned);
        p.Add("UpdatedBy",    _tenant.UserId);
        await conn.ExecuteAsync("sp_Role_Update", p, commandType: CommandType.StoredProcedure);
    }

    public async Task SavePermissionAsync(int roleId, string module, bool canView, bool canAdd, bool canEdit, bool canDelete)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("RoleId",       roleId);
        p.Add("Module",       module);
        p.Add("CanView",      canView);
        p.Add("CanAdd",       canAdd);
        p.Add("CanEdit",      canEdit);
        p.Add("CanDelete",    canDelete);
        await conn.ExecuteAsync("sp_RolePermission_Upsert", p, commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Role_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
