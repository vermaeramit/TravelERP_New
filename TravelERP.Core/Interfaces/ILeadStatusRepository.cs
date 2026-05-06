using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface ILeadStatusRepository
{
    Task<IEnumerable<LeadStatus>> GetAllAsync();
    Task<int> InsertAsync(LeadStatus status);
    Task UpdateAsync(LeadStatus status);
    Task DeleteAsync(int id);
}
