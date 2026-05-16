using TravelERP.Core.Entities.Master;

namespace TravelERP.Core.Interfaces;

public interface ISubscriptionPlanRepository
{
    Task<IEnumerable<SubscriptionPlan>> GetAllAsync(bool includeInactive = false);
    Task<SubscriptionPlan?> GetByIdAsync(int id);
    Task<int> InsertAsync(SubscriptionPlan plan);
    Task<bool> UpdateAsync(SubscriptionPlan plan);
    Task<bool> SetActiveAsync(int id, bool isActive);
    Task<bool> DeleteAsync(int id);
}
