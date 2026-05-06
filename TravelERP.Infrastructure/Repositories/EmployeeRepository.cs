using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class EmployeeRepository : IEmployeeRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public EmployeeRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<Employee>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Employee>(
            "sp_Employee_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Employee?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Employee>(
            "sp_Employee_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Employee e)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",  _tenant.DatabaseName);
        p.Add("UserId",        e.UserId);
        p.Add("DesignationId", e.DesignationId);
        p.Add("FirstName",     e.FirstName);
        p.Add("LastName",      e.LastName);
        p.Add("Email",         e.Email);
        p.Add("Mobile",        e.Mobile);
        p.Add("DateOfBirth",   e.DateOfBirth, DbType.Date);
        p.Add("ImageUrl",      e.ImageUrl);
        p.Add("ReplyEmail",    e.ReplyEmail);
        p.Add("CreatedBy",     _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Employee_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(Employee e)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",  _tenant.DatabaseName);
        p.Add("Id",            e.Id);
        p.Add("DesignationId", e.DesignationId);
        p.Add("FirstName",     e.FirstName);
        p.Add("LastName",      e.LastName);
        p.Add("Email",         e.Email);
        p.Add("Mobile",        e.Mobile);
        p.Add("DateOfBirth",   e.DateOfBirth, DbType.Date);
        p.Add("ImageUrl",      e.ImageUrl);
        p.Add("ReplyEmail",    e.ReplyEmail);
        p.Add("UpdatedBy",     _tenant.UserId);
        await conn.ExecuteAsync("sp_Employee_Update", p, commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Employee_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
