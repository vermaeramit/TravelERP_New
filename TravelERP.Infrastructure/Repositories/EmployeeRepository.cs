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

    public async Task<Employee?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Employee>(
            "sp_Employee_GetById", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Employee>> GetAllAsync(int? branchId = null)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Employee>(
            "sp_Employee_GetAll",
            new { DatabaseName = _tenant.DatabaseName, BranchId = branchId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Employee>> GetByDepartmentAsync(string department)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Employee>(
            "sp_Employee_GetByDepartment",
            new { DatabaseName = _tenant.DatabaseName, Department = department },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Employee employee)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(employee);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Employee_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(Employee employee)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(employee);
        p.Add("DatabaseName", _tenant.DatabaseName);
        return await conn.ExecuteAsync(
            "sp_Employee_Update", p, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Employee_Delete", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<string> GenerateEmployeeCodeAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<string>(
            "sp_Employee_GenerateCode", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure) ?? "EMP00001";
    }

    public async Task<int> GetTotalCountAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<int>(
            "sp_Employee_GetTotalCount", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertLeaveRequestAsync(LeaveRequest leave)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(leave);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Leave_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<IEnumerable<LeaveRequest>> GetLeavesByEmployeeAsync(int employeeId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<LeaveRequest>(
            "sp_Leave_GetByEmployee",
            new { DatabaseName = _tenant.DatabaseName, EmployeeId = employeeId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<LeaveRequest>> GetPendingLeavesAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<LeaveRequest>(
            "sp_Leave_GetPending", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<bool> UpdateLeaveStatusAsync(int leaveId, int status, int approvedById, string remarks)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync("sp_Leave_UpdateStatus",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                Id = leaveId, Status = status,
                ApprovedById = approvedById, ApproverRemarks = remarks,
                ActionDate = DateTime.UtcNow
            },
            commandType: CommandType.StoredProcedure) > 0;
    }
}
