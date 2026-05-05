using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class CustomerRepository : ICustomerRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public CustomerRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<Customer?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Customer>(
            "sp_Customer_GetById", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Customer>> GetAllAsync(int? branchId = null)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Customer>(
            "sp_Customer_GetAll", new { DatabaseName = _tenant.DatabaseName, BranchId = branchId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Customer>> SearchAsync(string keyword)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Customer>(
            "sp_Customer_Search", new { DatabaseName = _tenant.DatabaseName, Keyword = keyword },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Customer customer)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",     _tenant.DatabaseName);
        p.Add("CustomerCode",     customer.CustomerCode);
        p.Add("Name",             customer.Name);
        p.Add("Mobile",           customer.Mobile);
        p.Add("Email",            customer.Email);
        p.Add("Destination",      customer.Destination);
        p.Add("TravelingDate",    customer.TravelingDate);
        p.Add("LeavingFrom",      customer.LeavingFrom);
        p.Add("TravelCity",       customer.TravelCity);
        p.Add("HotelRecommended", customer.HotelRecommended);
        p.Add("NoOfAdults",       customer.NoOfAdults);
        p.Add("NoOfChildren",     customer.NoOfChildren);
        p.Add("NoOfDays",         customer.NoOfDays);
        p.Add("AssignedTo",       customer.AssignedTo);
        p.Add("LeadSource",       customer.LeadSource);
        p.Add("Infant",           customer.Infant);
        p.Add("Remark",           customer.Remark);
        p.Add("PassportNumber",   customer.PassportNumber);
        p.Add("PassportExpiry",   customer.PassportExpiry);
        p.Add("Notes",            customer.Notes);
        p.Add("CreatedAt",        customer.CreatedAt);
        p.Add("CreatedBy",        customer.CreatedBy);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Customer_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(Customer customer)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",     _tenant.DatabaseName);
        p.Add("Id",               customer.Id);
        p.Add("Name",             customer.Name);
        p.Add("Mobile",           customer.Mobile);
        p.Add("Email",            customer.Email);
        p.Add("Destination",      customer.Destination);
        p.Add("TravelingDate",    customer.TravelingDate);
        p.Add("LeavingFrom",      customer.LeavingFrom);
        p.Add("TravelCity",       customer.TravelCity);
        p.Add("HotelRecommended", customer.HotelRecommended);
        p.Add("NoOfAdults",       customer.NoOfAdults);
        p.Add("NoOfChildren",     customer.NoOfChildren);
        p.Add("NoOfDays",         customer.NoOfDays);
        p.Add("AssignedTo",       customer.AssignedTo);
        p.Add("LeadSource",       customer.LeadSource);
        p.Add("Infant",           customer.Infant);
        p.Add("Remark",           customer.Remark);
        p.Add("PassportNumber",   customer.PassportNumber);
        p.Add("PassportExpiry",   customer.PassportExpiry);
        p.Add("Notes",            customer.Notes);
        p.Add("UpdatedAt",        customer.UpdatedAt);
        p.Add("UpdatedBy",        customer.UpdatedBy);
        return await conn.ExecuteAsync(
            "sp_Customer_Update", p, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Customer_Delete", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<string> GenerateCustomerCodeAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<string>(
            "sp_Customer_GenerateCode", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure) ?? "CUS00001";
    }

    public async Task<int> GetTotalCountAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<int>(
            "sp_Customer_GetTotalCount", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }
}
