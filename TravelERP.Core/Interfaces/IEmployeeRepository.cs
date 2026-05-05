using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IEmployeeRepository
{
    Task<Employee?> GetByIdAsync(int id);
    Task<IEnumerable<Employee>> GetAllAsync(int? branchId = null);
    Task<IEnumerable<Employee>> GetByDepartmentAsync(string department);
    Task<int> InsertAsync(Employee employee);
    Task<bool> UpdateAsync(Employee employee);
    Task<bool> DeleteAsync(int id);
    Task<string> GenerateEmployeeCodeAsync();
    Task<int> GetTotalCountAsync();
    Task<int> InsertLeaveRequestAsync(LeaveRequest leave);
    Task<IEnumerable<LeaveRequest>> GetLeavesByEmployeeAsync(int employeeId);
    Task<IEnumerable<LeaveRequest>> GetPendingLeavesAsync();
    Task<bool> UpdateLeaveStatusAsync(int leaveId, int status, int approvedById, string remarks);
}
