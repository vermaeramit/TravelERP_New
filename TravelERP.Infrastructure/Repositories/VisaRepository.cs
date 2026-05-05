using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class VisaRepository : IVisaRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public VisaRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<VisaApplication?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<VisaApplication>(
            "sp_Visa_GetById", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<VisaApplication>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<VisaApplication>(
            "sp_Visa_GetAll", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<VisaApplication>> GetByCustomerAsync(int customerId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<VisaApplication>(
            "sp_Visa_GetByCustomer",
            new { DatabaseName = _tenant.DatabaseName, CustomerId = customerId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(VisaApplication visa)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(visa);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Visa_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(VisaApplication visa)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(visa);
        p.Add("DatabaseName", _tenant.DatabaseName);
        return await conn.ExecuteAsync(
            "sp_Visa_Update", p, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateStatusAsync(int id, int status, string? notes)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Visa_UpdateStatus",
            new { DatabaseName = _tenant.DatabaseName, Id = id, Status = status, Notes = notes },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<int> InsertDocumentAsync(PassengerDocument doc)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(doc);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Document_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<IEnumerable<PassengerDocument>> GetDocumentsByCustomerAsync(int customerId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<PassengerDocument>(
            "sp_Document_GetByCustomer",
            new { DatabaseName = _tenant.DatabaseName, CustomerId = customerId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<bool> DeleteDocumentAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Document_Delete", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure) > 0;
    }
}
