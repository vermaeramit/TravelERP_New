using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class ActivityTemplateRepository : IActivityTemplateRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public ActivityTemplateRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<ActivityTemplate>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<ActivityTemplate>(
            "sp_ActivityTemplate_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<ActivityTemplate?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<ActivityTemplate>(
            "sp_ActivityTemplate_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(ActivityTemplate t)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("Name",         t.Name);
        p.Add("ActivityType", t.ActivityType);
        p.Add("Subject",      t.Subject);
        p.Add("Notes",        t.Notes);
        p.Add("DisplayOrder", t.DisplayOrder);
        p.Add("CreatedBy",    _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_ActivityTemplate_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(ActivityTemplate t)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_ActivityTemplate_Update",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                t.Id, t.Name, t.ActivityType, t.Subject, t.Notes, t.DisplayOrder,
                UpdatedBy = _tenant.UserId
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_ActivityTemplate_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
