using TravelERP.Shared.DTOs;

namespace TravelERP.Core.Interfaces;

public interface IDashboardRepository
{
    Task<DashboardStatsDto> GetStatsAsync();
    Task<IEnumerable<MonthlyRevenueDto>> GetMonthlyRevenueAsync(int year);
    Task<IEnumerable<BookingStatusChartDto>> GetBookingStatusChartAsync();
    Task<IEnumerable<RecentBookingDto>> GetRecentBookingsAsync(int count = 10);
    Task<IEnumerable<TopPackageDto>> GetTopPackagesAsync(int count = 5);
}
