using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IDesignationRepository
{
    Task<IEnumerable<Designation>> GetAllAsync();
    Task<int> InsertAsync(Designation designation);
    Task UpdateAsync(Designation designation);
    Task DeleteAsync(int id);
}
