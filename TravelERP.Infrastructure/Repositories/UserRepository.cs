using System.Data;
using Dapper;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly DbConnectionFactory _factory;

    public UserRepository(DbConnectionFactory factory) => _factory = factory;

    public async Task<MasterUser?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<MasterUser>(
            "sp_User_GetById", new { Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<MasterUser?> GetByEmailAsync(string email)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<MasterUser>(
            "sp_User_GetByEmail", new { Email = email },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<MasterUser>> GetByCompanyAsync(int companyId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<MasterUser>(
            "sp_User_GetByCompany", new { CompanyId = companyId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(MasterUser user)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("CompanyId",       user.CompanyId);
        p.Add("FullName",        user.FullName);
        p.Add("Email",           user.Email);
        p.Add("PasswordHash",    user.PasswordHash);
        p.Add("Role",            (byte)user.Role);
        p.Add("IsActive",        user.IsActive);
        p.Add("ProfileImageUrl", user.ProfileImageUrl);
        p.Add("CreatedAt",       user.CreatedAt);
        p.Add("CreatedBy",       user.CreatedBy);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_User_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(MasterUser user)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_User_Update", user, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateLastLoginAsync(int userId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_User_UpdateLastLogin", new { Id = userId },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> ChangePasswordAsync(int userId, string passwordHash)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_User_ChangePassword", new { Id = userId, PasswordHash = passwordHash },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task SetTenantRoleAsync(int userId, int tenantRoleId)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_User_SetTenantRole", new { Id = userId, TenantRoleId = tenantRoleId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id, int? deletedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_User_Delete", new { Id = id, UpdatedBy = deletedBy },
            commandType: CommandType.StoredProcedure);
    }
}
