using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IDestinationRepository
{
    Task<IEnumerable<Destination>> GetAllAsync();
    Task<Destination?> GetByIdAsync(int id);
    Task<int> InsertAsync(Destination destination);
    Task UpdateAsync(Destination destination);
    Task DeleteAsync(int id);
    Task ReplaceReviewsAsync(int destinationId, IEnumerable<DestinationReview> reviews);
}
