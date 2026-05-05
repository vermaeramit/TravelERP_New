using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class InvoiceRepository : IInvoiceRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public InvoiceRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<Invoice?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Invoice>(
            "sp_Invoice_GetById", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Invoice>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Invoice>(
            "sp_Invoice_GetAll", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Invoice>> GetByBookingAsync(int bookingId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Invoice>(
            "sp_Invoice_GetByBooking",
            new { DatabaseName = _tenant.DatabaseName, BookingId = bookingId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Invoice>> GetByCustomerAsync(int customerId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Invoice>(
            "sp_Invoice_GetByCustomer",
            new { DatabaseName = _tenant.DatabaseName, CustomerId = customerId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Invoice invoice)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(invoice);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Invoice_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(Invoice invoice)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(invoice);
        p.Add("DatabaseName", _tenant.DatabaseName);
        return await conn.ExecuteAsync(
            "sp_Invoice_Update", p, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<string> GenerateInvoiceNumberAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<string>(
            "sp_Invoice_GenerateNumber", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure) ?? "INV00001";
    }

    public async Task<int> InsertPaymentAsync(Payment payment)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(payment);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Payment_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<IEnumerable<Payment>> GetPaymentsByInvoiceAsync(int invoiceId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Payment>(
            "sp_Payment_GetByInvoice",
            new { DatabaseName = _tenant.DatabaseName, InvoiceId = invoiceId },
            commandType: CommandType.StoredProcedure);
    }
}
