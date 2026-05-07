namespace TravelERP.Web.Models;

public class DashboardVm
{
    public DashboardKpis Kpis { get; set; } = new();
    public List<RevenuePoint> RevenueTrend { get; set; } = [];
    public List<LeadStatusSlice> LeadsByStatus { get; set; } = [];
    public List<RecentLead> RecentLeads { get; set; } = [];
    public List<UpcomingBooking> UpcomingTravel { get; set; } = [];
    public List<OverdueInstallment> OverdueInstallments { get; set; } = [];
    public string Currency { get; set; } = "INR";
}

public class DashboardKpis
{
    public int TotalLeads { get; set; }
    public int ActiveLeads { get; set; }
    public int NewLeadsThisWeek { get; set; }
    public int BookingsThisMonth { get; set; }
    public decimal RevenueThisMonth { get; set; }
    public decimal OutstandingBalance { get; set; }
    public int OverdueInstallmentsCount { get; set; }
    public decimal OverdueAmount { get; set; }
    public int TotalPackages { get; set; }
    public decimal CollectedThisMonth { get; set; }
}

public class RevenuePoint
{
    public int YearNo { get; set; }
    public int MonthNo { get; set; }
    public string MonthLabel { get; set; } = "";
    public decimal Revenue { get; set; }
    public int BookingCount { get; set; }
}

public class LeadStatusSlice
{
    public string StatusName { get; set; } = "";
    public string StatusColor { get; set; } = "secondary";
    public int LeadCount { get; set; }
}

public class RecentLead
{
    public int Id { get; set; }
    public string LeadNumber { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Mobile { get; set; }
    public DateTime CreatedAt { get; set; }
    public string StatusName { get; set; } = "";
    public string StatusColor { get; set; } = "secondary";
    public string? DestinationName { get; set; }
}

public class UpcomingBooking
{
    public int Id { get; set; }
    public string BookingNumber { get; set; } = "";
    public string CustomerName { get; set; } = "";
    public DateTime? StartDate { get; set; }
    public int? Days { get; set; }
    public decimal TotalAmount { get; set; }
    public string Currency { get; set; } = "INR";
    public string Status { get; set; } = "";
    public string? DestinationName { get; set; }
}

public class MonthlyTotals
{
    public int YearNo { get; set; }
    public int MonthNo { get; set; }
    public string MonthLabel { get; set; } = "";
    public int TotalLeads { get; set; }
    public int TotalNotes { get; set; }
    public int TotalQuotes { get; set; }
}

public class MonthlyStatus
{
    public int YearNo { get; set; }
    public int MonthNo { get; set; }
    public string StatusName { get; set; } = "";
    public string StatusColor { get; set; } = "secondary";
    public int LeadCount { get; set; }
}

public class RangeTotals
{
    public int TotalLeads { get; set; }
    public int TotalNotes { get; set; }
    public int TotalQuotes { get; set; }
}

public class OverdueInstallment
{
    public int Id { get; set; }
    public int BookingId { get; set; }
    public int InstallmentNo { get; set; }
    public decimal Amount { get; set; }
    public DateTime? DueDate { get; set; }
    public int DaysOverdue { get; set; }
    public string BookingNumber { get; set; } = "";
    public string CustomerName { get; set; } = "";
    public string Currency { get; set; } = "INR";
}
