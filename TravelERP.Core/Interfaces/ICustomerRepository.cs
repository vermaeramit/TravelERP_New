using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface ICustomerRepository
{
    Task<Customer?> GetByIdAsync(int id);
    Task<IEnumerable<Customer>> GetAllAsync(int? branchId = null);
    Task<IEnumerable<Customer>> SearchAsync(string keyword);
    Task<int> InsertAsync(Customer customer);
    Task<bool> UpdateAsync(Customer customer);
    Task<bool> DeleteAsync(int id);
    Task<string> GenerateCustomerCodeAsync();
    Task<int> GetTotalCountAsync();
}
