using TravelERP.Core.Entities.Tenant;
using TravelERP.Shared.Enums;

namespace TravelERP.Core.Interfaces;

public interface IBookingRepository
{
    Task<Booking?> GetByIdAsync(int id);
    Task<Booking?> GetByReferenceAsync(string reference);
    Task<IEnumerable<Booking>> GetAllAsync(int? branchId = null);
    Task<IEnumerable<Booking>> GetByCustomerAsync(int customerId);
    Task<IEnumerable<Booking>> GetByStatusAsync(BookingStatus status);
    Task<IEnumerable<Booking>> GetByDateRangeAsync(DateTime from, DateTime to);
    Task<int> InsertAsync(Booking booking);
    Task<bool> UpdateAsync(Booking booking);
    Task<bool> UpdateStatusAsync(int id, BookingStatus status);
    Task<string> GenerateBookingReferenceAsync();
    Task<decimal> GetTotalRevenueAsync(DateTime? from = null, DateTime? to = null);
    Task<int> GetTotalCountAsync();
}
