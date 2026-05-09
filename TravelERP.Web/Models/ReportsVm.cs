namespace TravelERP.Web.Models;

public class ReportsVm
{
    public DateTime From { get; set; }
    public DateTime To   { get; set; }
    public string Currency { get; set; } = "INR";

    public SalesSummaryKpis Summary { get; set; } = new();
    public List<SalesMonthlyPoint> MonthlyTrend { get; set; } = [];
    public List<SalesByGroupRow> ByDestination { get; set; } = [];
    public List<SalesByGroupRow> ByAgent { get; set; } = [];
    public List<AgingBucketRow> AgingBuckets { get; set; } = [];
    public List<AgingDetailRow> AgingDetails { get; set; } = [];
}

public class SalesSummaryKpis
{
    public int BookingCount { get; set; }
    public decimal TotalRevenue { get; set; }
    public decimal AvgBookingValue { get; set; }
    public decimal Collected { get; set; }
    public int LeadCount { get; set; }
}

public class SalesMonthlyPoint
{
    public int YearNo { get; set; }
    public int MonthNo { get; set; }
    public string MonthLabel { get; set; } = "";
    public int BookingCount { get; set; }
    public decimal Revenue { get; set; }
}

public class SalesByGroupRow
{
    public string DestinationName { get; set; } = "";   // also used as AgentName by mapping in repo (see Dapper)
    public string AgentName { get; set; } = "";
    public int BookingCount { get; set; }
    public decimal TotalRevenue { get; set; }
    public decimal AvgBookingValue { get; set; }
}

public class AgingBucketRow
{
    public string Bucket { get; set; } = "";
    public int BucketOrder { get; set; }
    public int InstallmentCount { get; set; }
    public decimal Outstanding { get; set; }
}

public class AgingDetailRow
{
    public int BookingId { get; set; }
    public string BookingNumber { get; set; } = "";
    public string CustomerName { get; set; } = "";
    public string Currency { get; set; } = "INR";
    public int InstallmentNo { get; set; }
    public decimal Amount { get; set; }
    public DateTime? DueDate { get; set; }
    public int DaysOverdue { get; set; }
}
