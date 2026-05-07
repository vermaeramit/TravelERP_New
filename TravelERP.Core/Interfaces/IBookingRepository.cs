using TravelERP.Core.Common;
using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IBookingRepository
{
    Task<PagedResult<Booking>> GetPagedAsync(string? search, string? status, int page, int pageSize);
    Task<IEnumerable<Booking>> GetByLeadAsync(int leadId);
    Task<Booking?> GetByIdAsync(int id);
    Task<(int Id, string BookingNumber, string InvoiceNumber)> InsertAsync(Booking booking);
    Task UpdateAsync(Booking booking);
    Task DeleteAsync(int id);
}
