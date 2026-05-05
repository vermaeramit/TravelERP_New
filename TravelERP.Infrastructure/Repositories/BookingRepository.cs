using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;
using TravelERP.Shared.Enums;

namespace TravelERP.Infrastructure.Repositories;

public class BookingRepository : IBookingRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public BookingRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<Booking?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Booking>(
            "sp_Booking_GetById", new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Booking?> GetByReferenceAsync(string reference)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Booking>(
            "sp_Booking_GetByReference",
            new { DatabaseName = _tenant.DatabaseName, BookingReference = reference },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Booking>> GetAllAsync(int? branchId = null)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Booking>(
            "sp_Booking_GetAll", new { DatabaseName = _tenant.DatabaseName, BranchId = branchId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Booking>> GetByCustomerAsync(int customerId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Booking>(
            "sp_Booking_GetByCustomer",
            new { DatabaseName = _tenant.DatabaseName, CustomerId = customerId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Booking>> GetByStatusAsync(BookingStatus status)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Booking>(
            "sp_Booking_GetByStatus",
            new { DatabaseName = _tenant.DatabaseName, Status = (int)status },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Booking>> GetByDateRangeAsync(DateTime from, DateTime to)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Booking>(
            "sp_Booking_GetByDateRange",
            new { DatabaseName = _tenant.DatabaseName, FromDate = from, ToDate = to },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Booking booking)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(booking);
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Booking_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(Booking booking)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters(booking);
        p.Add("DatabaseName", _tenant.DatabaseName);
        return await conn.ExecuteAsync(
            "sp_Booking_Update", p, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateStatusAsync(int id, BookingStatus status)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Booking_UpdateStatus",
            new { DatabaseName = _tenant.DatabaseName, Id = id, Status = (int)status },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<string> GenerateBookingReferenceAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<string>(
            "sp_Booking_GenerateReference", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure) ?? "BK000001";
    }

    public async Task<decimal> GetTotalRevenueAsync(DateTime? from = null, DateTime? to = null)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<decimal>(
            "sp_Booking_GetTotalRevenue",
            new { DatabaseName = _tenant.DatabaseName, FromDate = from, ToDate = to },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> GetTotalCountAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<int>(
            "sp_Booking_GetTotalCount", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }
}
