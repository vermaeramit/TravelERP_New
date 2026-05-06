using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface ISightseeingRepository
{
    Task<IEnumerable<Sightseeing>> GetAllAsync();
    Task<Sightseeing?> GetByIdAsync(int id);
    Task<int> InsertAsync(Sightseeing sightseeing);
    Task UpdateAsync(Sightseeing sightseeing);
    Task DeleteAsync(int id);
}
