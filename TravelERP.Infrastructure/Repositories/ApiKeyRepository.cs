using System.Data;
using Dapper;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class ApiKeyRepository : IApiKeyRepository
{
    private readonly DbConnectionFactory _factory;

    public ApiKeyRepository(DbConnectionFactory factory) => _factory = factory;

    public async Task<IEnumerable<ApiKey>> GetByCompanyAsync(int companyId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<ApiKey>(
            "sp_ApiKey_GetByCompany", new { CompanyId = companyId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<ApiKey?> GetByKeyAsync(string apiKey)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<ApiKey>(
            "sp_ApiKey_GetByKey", new { ApiKey = apiKey },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(ApiKey key)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("CompanyId", key.CompanyId);
        p.Add("Name",      key.Name);
        p.Add("ApiKey",    key.Key);
        p.Add("CreatedBy", key.CreatedBy);
        p.Add("ExpiresAt", key.ExpiresAt);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_ApiKey_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task RevokeAsync(int id, int companyId)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync("sp_ApiKey_Revoke",
            new { Id = id, CompanyId = companyId }, commandType: CommandType.StoredProcedure);
    }

    public async Task MarkUsedAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync("sp_ApiKey_MarkUsed", new { Id = id }, commandType: CommandType.StoredProcedure);
    }
}
