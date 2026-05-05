using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IInvoiceRepository
{
    Task<Invoice?> GetByIdAsync(int id);
    Task<IEnumerable<Invoice>> GetAllAsync();
    Task<IEnumerable<Invoice>> GetByBookingAsync(int bookingId);
    Task<IEnumerable<Invoice>> GetByCustomerAsync(int customerId);
    Task<int> InsertAsync(Invoice invoice);
    Task<bool> UpdateAsync(Invoice invoice);
    Task<string> GenerateInvoiceNumberAsync();
    Task<int> InsertPaymentAsync(Payment payment);
    Task<IEnumerable<Payment>> GetPaymentsByInvoiceAsync(int invoiceId);
}
