using System.Data;
using Dapper;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class SubscriptionPlanRepository : ISubscriptionPlanRepository
{
    private readonly DbConnectionFactory _factory;

    public SubscriptionPlanRepository(DbConnectionFactory factory) => _factory = factory;

    public async Task<IEnumerable<SubscriptionPlan>> GetAllAsync(bool includeInactive = false)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<SubscriptionPlan>(
            "sp_Plan_GetAll", new { IncludeInactive = includeInactive },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<SubscriptionPlan?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<SubscriptionPlan>(
            "sp_Plan_GetById", new { Id = id }, commandType: CommandType.StoredProcedure);
    }

    private static DynamicParameters BuildParams(SubscriptionPlan plan)
    {
        var p = new DynamicParameters();
        p.Add("Name",         plan.Name);
        p.Add("MonthlyPrice", plan.MonthlyPrice);
        p.Add("YearlyPrice",  plan.YearlyPrice);
        p.Add("MaxUsers",     plan.MaxUsers);
        p.Add("Features",     plan.Features);
        p.Add("IsActive",     plan.IsActive);
        p.Add("Tagline",      plan.Tagline);
        p.Add("IconClass",    plan.IconClass);
        p.Add("IconColor",    plan.IconColor);
        p.Add("IsFeatured",   plan.IsFeatured);
        p.Add("DisplayOrder", plan.DisplayOrder);
        p.Add("CtaLabel",     plan.CtaLabel);
        p.Add("CtaUrl",       plan.CtaUrl);
        return p;
    }

    public async Task<int> InsertAsync(SubscriptionPlan plan)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = BuildParams(plan);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Plan_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(SubscriptionPlan plan)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = BuildParams(plan);
        p.Add("Id", plan.Id);
        return await conn.ExecuteAsync(
            "sp_Plan_Update", p, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> SetActiveAsync(int id, bool isActive)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Plan_SetActive", new { Id = id, IsActive = isActive },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Plan_Delete", new { Id = id }, commandType: CommandType.StoredProcedure) > 0;
    }
}
