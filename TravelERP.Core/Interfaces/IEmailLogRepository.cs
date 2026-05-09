using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IEmailLogRepository
{
    Task<int> InsertAsync(EmailLog log);
    Task<IEnumerable<EmailLog>> GetByRelatedAsync(string relatedType, int relatedId, int top = 10);
}
