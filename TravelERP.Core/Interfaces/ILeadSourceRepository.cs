using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface ILeadSourceRepository
{
    Task<IEnumerable<LeadSource>> GetAllAsync();
    Task<int> InsertAsync(LeadSource source);
    Task UpdateAsync(LeadSource source);
    Task DeleteAsync(int id);
}
