using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class HotelRepository : IHotelRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public HotelRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<Hotel>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Hotel>(
            "sp_Hotel_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Hotel?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Hotel>(
            "sp_Hotel_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Hotel hotel)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",  _tenant.DatabaseName);
        p.Add("DestinationId", hotel.DestinationId);
        p.Add("Name",          hotel.Name);
        p.Add("Category",      hotel.Category);
        p.Add("ImageUrl",      hotel.ImageUrl);
        p.Add("CreatedBy",     _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Hotel_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(Hotel hotel)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Hotel_Update",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                hotel.Id, hotel.DestinationId, hotel.Name, hotel.Category, hotel.ImageUrl,
                UpdatedBy = _tenant.UserId
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Hotel_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
