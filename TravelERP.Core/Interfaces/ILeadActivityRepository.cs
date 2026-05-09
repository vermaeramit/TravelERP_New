using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface ILeadActivityRepository
{
    Task<IEnumerable<LeadActivity>> GetByLeadAsync(int leadId);
    Task<LeadActivity?> GetByIdAsync(int id);
    Task<int> InsertAsync(LeadActivity activity);
    Task UpdateAsync(LeadActivity activity);
    Task CompleteAsync(int id);
    Task DeleteAsync(int id);
    Task<TodayPanel> GetTodayPanelAsync(int? userId, bool myOnly);
}
