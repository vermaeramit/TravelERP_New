using TravelERP.Shared.Enums;

namespace TravelERP.Core.Entities.Tenant;

public class LeaveRequest : BaseEntity
{
    public int EmployeeId { get; set; }
    public LeaveType LeaveType { get; set; }
    public DateTime FromDate { get; set; }
    public DateTime ToDate { get; set; }
    public int TotalDays { get; set; }
    public string Reason { get; set; } = string.Empty;
    public LeaveStatus Status { get; set; } = LeaveStatus.Pending;
    public int? ApprovedById { get; set; }
    public string? ApproverRemarks { get; set; }
    public DateTime? ActionDate { get; set; }
}
