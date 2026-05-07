using System.Data;
using Dapper;
using TravelERP.Core.Common;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class BookingRepository : IBookingRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;
    private readonly ICompanyRepository _companies;

    public BookingRepository(DbConnectionFactory factory, ITenantContext tenant, ICompanyRepository companies)
    {
        _factory = factory;
        _tenant = tenant;
        _companies = companies;
    }

    public async Task<PagedResult<Booking>> GetPagedAsync(string? search, string? status, int page, int pageSize)
    {
        using var conn = _factory.CreateMasterConnection();
        var rows = (await conn.QueryAsync<Booking>(
            "sp_Booking_GetAll",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                Search   = string.IsNullOrWhiteSpace(search) ? null : search.Trim(),
                Status   = string.IsNullOrWhiteSpace(status) ? null : status.Trim(),
                Page     = page < 1 ? 1 : page,
                PageSize = pageSize is < 5 or > 100 ? 20 : pageSize
            },
            commandType: CommandType.StoredProcedure)).ToList();

        return new PagedResult<Booking>
        {
            Items    = rows,
            Page     = page < 1 ? 1 : page,
            PageSize = pageSize is < 5 or > 100 ? 20 : pageSize,
            Total    = rows.FirstOrDefault()?.TotalCount ?? 0
        };
    }

    public async Task<IEnumerable<Booking>> GetByLeadAsync(int leadId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Booking>(
            "sp_Booking_GetByLead",
            new { DatabaseName = _tenant.DatabaseName, LeadId = leadId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Booking?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        using var multi = await conn.QueryMultipleAsync(
            "sp_Booking_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);

        var booking = await multi.ReadSingleOrDefaultAsync<Booking>();
        if (booking == null) return null;

        booking.Installments = (await multi.ReadAsync<BookingInstallment>()).ToList();
        booking.PaidAmount = booking.Installments
            .Where(i => string.Equals(i.PaymentStatus, "Received", StringComparison.OrdinalIgnoreCase))
            .Sum(i => i.Amount);
        return booking;
    }

    public async Task<(int Id, string BookingNumber, string InvoiceNumber)> InsertAsync(Booking b)
    {
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        using var conn = _factory.CreateMasterConnection();

        var p = new DynamicParameters();
        p.Add("DatabaseName",    _tenant.DatabaseName);
        p.Add("BookingPrefix",   company?.BookingPrefix ?? "BK");
        p.Add("InvoicePrefix",   company?.InvoicePrefix ?? "INV");
        p.Add("LeadId",          b.LeadId);
        p.Add("PackageId",       b.PackageId);
        p.Add("PackageOptionId", b.PackageOptionId);
        p.Add("OptionName",      b.OptionName);
        p.Add("CustomerName",    b.CustomerName);
        p.Add("CustomerMobile",  b.CustomerMobile);
        p.Add("CustomerEmail",   b.CustomerEmail);
        p.Add("Adults",          b.Adults);
        p.Add("Children",        b.Children);
        p.Add("Infants",         b.Infants);
        p.Add("StartDate",       b.StartDate, DbType.Date);
        p.Add("EndDate",         b.EndDate,   DbType.Date);
        p.Add("Days",            b.Days);
        p.Add("Nights",          b.Nights);
        p.Add("DestinationId",   b.DestinationId);
        p.Add("TotalAmount",     b.TotalAmount);
        p.Add("Currency",        b.Currency);
        p.Add("Status",          b.Status);
        p.Add("Notes",           b.Notes);
        p.Add("CreatedBy",       _tenant.UserId);
        p.Add("NewId",         dbType: DbType.Int32,  direction: ParameterDirection.Output);
        p.Add("BookingNumber", dbType: DbType.String, size: 40, direction: ParameterDirection.Output);
        p.Add("InvoiceNumber", dbType: DbType.String, size: 40, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Booking_Insert", p, commandType: CommandType.StoredProcedure);

        var newId = p.Get<int>("NewId");
        await SaveInstallmentsAsync(conn, newId, b.Installments);

        return (newId, p.Get<string>("BookingNumber"), p.Get<string>("InvoiceNumber"));
    }

    public async Task UpdateAsync(Booking b)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Booking_Update",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                b.Id, b.CustomerName, b.CustomerMobile, b.CustomerEmail,
                b.Adults, b.Children, b.Infants,
                StartDate = b.StartDate, EndDate = b.EndDate,
                b.Days, b.Nights, b.DestinationId,
                b.TotalAmount, b.Currency, b.Status, b.Notes,
                UpdatedBy = _tenant.UserId
            },
            commandType: CommandType.StoredProcedure);

        await SaveInstallmentsAsync(conn, b.Id, b.Installments);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Booking_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    private async Task SaveInstallmentsAsync(IDbConnection conn, int bookingId, IEnumerable<BookingInstallment> rows)
    {
        // Replace strategy — simpler than diffing rows; installment volume is low (<20 typical).
        await conn.ExecuteAsync(
            "sp_Booking_ReplaceInstallments",
            new { DatabaseName = _tenant.DatabaseName, BookingId = bookingId },
            commandType: CommandType.StoredProcedure);

        int n = 1;
        foreach (var i in rows)
        {
            if (i.Amount <= 0 && string.IsNullOrWhiteSpace(i.PaymentMode)) continue;
            await conn.ExecuteAsync(
                "sp_BookingInstallment_Insert",
                new
                {
                    DatabaseName  = _tenant.DatabaseName,
                    BookingId     = bookingId,
                    InstallmentNo = i.InstallmentNo > 0 ? i.InstallmentNo : n,
                    i.Amount,
                    i.PaymentMode,
                    PaymentStatus = string.IsNullOrWhiteSpace(i.PaymentStatus) ? "Pending" : i.PaymentStatus,
                    DueDate       = i.DueDate,
                    ReceivedDate  = i.ReceivedDate,
                    i.Remark,
                    CreatedBy     = _tenant.UserId
                },
                commandType: CommandType.StoredProcedure);
            n++;
        }
    }
}
