using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class SightseeingRepository : ISightseeingRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public SightseeingRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<Sightseeing>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Sightseeing>(
            "sp_Sightseeing_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Sightseeing?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Sightseeing>(
            "sp_Sightseeing_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Sightseeing s)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",  _tenant.DatabaseName);
        p.Add("DestinationId", s.DestinationId);
        p.Add("Name",          s.Name);
        p.Add("ImageUrl",      s.ImageUrl);
        p.Add("CreatedBy",     _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Sightseeing_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(Sightseeing s)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Sightseeing_Update",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                s.Id, s.DestinationId, s.Name, s.ImageUrl,
                UpdatedBy = _tenant.UserId
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Sightseeing_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
