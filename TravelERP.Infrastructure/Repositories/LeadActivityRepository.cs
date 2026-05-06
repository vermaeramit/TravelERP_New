using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class LeadActivityRepository : ILeadActivityRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public LeadActivityRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<LeadActivity>> GetByLeadAsync(int leadId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<LeadActivity>(
            "sp_LeadActivity_GetByLead",
            new { DatabaseName = _tenant.DatabaseName, LeadId = leadId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<LeadActivity?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<LeadActivity>(
            "sp_LeadActivity_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(LeadActivity a)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",    _tenant.DatabaseName);
        p.Add("LeadId",          a.LeadId);
        p.Add("ActivityType",    a.ActivityType);
        p.Add("Subject",         a.Subject);
        p.Add("Notes",           a.Notes);
        p.Add("ActivityAt",      a.ActivityAt == default ? null : (DateTime?)a.ActivityAt);
        p.Add("NextFollowUpAt",  a.NextFollowUpAt);
        p.Add("IsCompleted",     a.IsCompleted);
        p.Add("CreatedByUserId", _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_LeadActivity_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(LeadActivity a)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_LeadActivity_Update",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                a.Id, a.ActivityType, a.Subject, a.Notes, a.ActivityAt, a.NextFollowUpAt, a.IsCompleted
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task CompleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_LeadActivity_Complete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_LeadActivity_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
