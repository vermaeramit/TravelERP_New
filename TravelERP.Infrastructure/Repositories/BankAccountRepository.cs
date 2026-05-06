using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class BankAccountRepository : IBankAccountRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public BankAccountRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<BankAccount>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<BankAccount>(
            "sp_BankAccount_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<BankAccount?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<BankAccount>(
            "sp_BankAccount_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(BankAccount a)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",  _tenant.DatabaseName);
        p.Add("BankName",      a.BankName);
        p.Add("HolderName",    a.HolderName);
        p.Add("AccountNumber", a.AccountNumber);
        p.Add("IfscCode",      a.IfscCode);
        p.Add("Branch",        a.Branch);
        p.Add("AccountType",   a.AccountType);
        p.Add("UpiId",         a.UpiId);
        p.Add("IsDefault",     a.IsDefault);
        p.Add("CreatedBy",     _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_BankAccount_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(BankAccount a)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_BankAccount_Update",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                a.Id, a.BankName, a.HolderName, a.AccountNumber,
                a.IfscCode, a.Branch, a.AccountType, a.UpiId, a.IsDefault,
                UpdatedBy = _tenant.UserId
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_BankAccount_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
