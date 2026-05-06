using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class LeadStatusRepository : ILeadStatusRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public LeadStatusRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<LeadStatus>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<LeadStatus>(
            "sp_LeadStatus_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(LeadStatus s)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("Name",         s.Name);
        p.Add("Color",        s.Color);
        p.Add("DisplayOrder", s.DisplayOrder);
        p.Add("IsDefault",    s.IsDefault);
        p.Add("IsClosed",     s.IsClosed);
        p.Add("CreatedBy",    _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_LeadStatus_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(LeadStatus s)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_LeadStatus_Update",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                s.Id, s.Name, s.Color, s.DisplayOrder, s.IsDefault, s.IsClosed,
                UpdatedBy = _tenant.UserId
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_LeadStatus_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
