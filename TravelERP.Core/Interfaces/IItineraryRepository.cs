using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IItineraryRepository
{
    Task<IEnumerable<Itinerary>> GetAllAsync();
    Task<Itinerary?> GetByIdAsync(int id);
    Task<int> InsertAsync(Itinerary itinerary);
    Task UpdateAsync(Itinerary itinerary);
    Task DeleteAsync(int id);
}
