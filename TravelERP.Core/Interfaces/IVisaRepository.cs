using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IVisaRepository
{
    Task<VisaApplication?> GetByIdAsync(int id);
    Task<IEnumerable<VisaApplication>> GetAllAsync();
    Task<IEnumerable<VisaApplication>> GetByCustomerAsync(int customerId);
    Task<int> InsertAsync(VisaApplication visa);
    Task<bool> UpdateAsync(VisaApplication visa);
    Task<bool> UpdateStatusAsync(int id, int status, string? notes);
    Task<int> InsertDocumentAsync(PassengerDocument doc);
    Task<IEnumerable<PassengerDocument>> GetDocumentsByCustomerAsync(int customerId);
    Task<bool> DeleteDocumentAsync(int id);
}
