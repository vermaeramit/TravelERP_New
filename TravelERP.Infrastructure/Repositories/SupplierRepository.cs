using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class SupplierRepository : ISupplierRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public SupplierRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<Supplier?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Supplier>(
            "sp_Supplier_GetById", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Supplier>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Supplier>(
            "sp_Supplier_GetAll", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Supplier>> GetByCategoryAsync(string category)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Supplier>(
            "sp_Supplier_GetByCategory",
            new { DatabaseName = _tenant.DatabaseName, Category = category },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Supplier supplier)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(supplier);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Supplier_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(Supplier supplier)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(supplier);
        p.Add("DatabaseName", _tenant.DatabaseName);
        return await conn.ExecuteAsync(
            "sp_Supplier_Update", p, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Supplier_Delete", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<string> GenerateSupplierCodeAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<string>(
            "sp_Supplier_GenerateCode", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure) ?? "SUP00001";
    }
}
