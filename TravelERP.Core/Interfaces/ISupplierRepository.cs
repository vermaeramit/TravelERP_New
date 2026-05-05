using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface ISupplierRepository
{
    Task<Supplier?> GetByIdAsync(int id);
    Task<IEnumerable<Supplier>> GetAllAsync();
    Task<IEnumerable<Supplier>> GetByCategoryAsync(string category);
    Task<int> InsertAsync(Supplier supplier);
    Task<bool> UpdateAsync(Supplier supplier);
    Task<bool> DeleteAsync(int id);
    Task<string> GenerateSupplierCodeAsync();
}
