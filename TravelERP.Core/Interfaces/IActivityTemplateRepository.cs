using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IActivityTemplateRepository
{
    Task<IEnumerable<ActivityTemplate>> GetAllAsync();
    Task<ActivityTemplate?> GetByIdAsync(int id);
    Task<int> InsertAsync(ActivityTemplate template);
    Task UpdateAsync(ActivityTemplate template);
    Task DeleteAsync(int id);
}
