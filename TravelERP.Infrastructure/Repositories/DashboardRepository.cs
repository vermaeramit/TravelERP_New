using System.Data;
using Dapper;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;
using TravelERP.Shared.DTOs;

namespace TravelERP.Infrastructure.Repositories;

public class DashboardRepository : IDashboardRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public DashboardRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<DashboardStatsDto> GetStatsAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<DashboardStatsDto>(
            "sp_Dashboard_GetStats", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure)
            ?? new DashboardStatsDto();
    }

    public async Task<IEnumerable<MonthlyRevenueDto>> GetMonthlyRevenueAsync(int year)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<MonthlyRevenueDto>(
            "sp_Dashboard_GetMonthlyRevenue",
            new { DatabaseName = _tenant.DatabaseName, Year = year },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<BookingStatusChartDto>> GetBookingStatusChartAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<BookingStatusChartDto>(
            "sp_Dashboard_GetBookingStatusChart", new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<RecentBookingDto>> GetRecentBookingsAsync(int count = 10)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<RecentBookingDto>(
            "sp_Dashboard_GetRecentBookings",
            new { DatabaseName = _tenant.DatabaseName, TopCount = count },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<TopPackageDto>> GetTopPackagesAsync(int count = 5)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<TopPackageDto>(
            "sp_Dashboard_GetTopPackages",
            new { DatabaseName = _tenant.DatabaseName, TopCount = count },
            commandType: CommandType.StoredProcedure);
    }
}
