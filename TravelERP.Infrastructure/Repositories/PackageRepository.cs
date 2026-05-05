using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;
using TravelERP.Shared.Enums;

namespace TravelERP.Infrastructure.Repositories;

public class PackageRepository : IPackageRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public PackageRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<TourPackage?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<TourPackage>(
            "sp_Package_GetById", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<TourPackage>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<TourPackage>(
            "sp_Package_GetAll", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<TourPackage>> GetByTypeAsync(PackageType type)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<TourPackage>(
            "sp_Package_GetByType",
            new { DatabaseName = _tenant.DatabaseName, Type = (int)type },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<TourPackage>> GetFeaturedAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<TourPackage>(
            "sp_Package_GetFeatured", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<TourPackage>> SearchAsync(string keyword)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<TourPackage>(
            "sp_Package_Search",
            new { DatabaseName = _tenant.DatabaseName, Keyword = keyword },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(TourPackage package)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(package);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Package_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(TourPackage package)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(package);
        p.Add("DatabaseName", _tenant.DatabaseName);
        return await conn.ExecuteAsync(
            "sp_Package_Update", p, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Package_Delete", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<string> GeneratePackageCodeAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<string>(
            "sp_Package_GenerateCode", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure) ?? "PKG00001";
    }
}
