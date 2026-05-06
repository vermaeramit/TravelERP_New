using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IMailTemplateRepository
{
    Task<IEnumerable<MailTemplate>> GetAllAsync();
    Task<MailTemplate?> GetByIdAsync(int id);
    Task<int> InsertAsync(MailTemplate template);
    Task UpdateAsync(MailTemplate template);
    Task DeleteAsync(int id);
}
