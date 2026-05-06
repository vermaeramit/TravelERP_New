using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IBankAccountRepository
{
    Task<IEnumerable<BankAccount>> GetAllAsync();
    Task<BankAccount?> GetByIdAsync(int id);
    Task<int> InsertAsync(BankAccount account);
    Task UpdateAsync(BankAccount account);
    Task DeleteAsync(int id);
}
