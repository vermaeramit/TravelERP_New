using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class MealPlanRepository : IMealPlanRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public MealPlanRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<MealPlan>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<MealPlan>(
            "sp_MealPlan_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(MealPlan m)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("Code",         m.Code);
        p.Add("Name",         m.Name);
        p.Add("CreatedBy",    _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_MealPlan_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(MealPlan m)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_MealPlan_Update",
            new { DatabaseName = _tenant.DatabaseName, m.Id, m.Code, m.Name, UpdatedBy = _tenant.UserId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_MealPlan_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
