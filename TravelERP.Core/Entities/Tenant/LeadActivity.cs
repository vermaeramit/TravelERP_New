namespace TravelERP.Core.Entities.Tenant;

public class LeadActivity
{
    public int Id { get; set; }
    public int LeadId { get; set; }
    public string ActivityType { get; set; } = ActivityTypes.Note;
    public string? Subject { get; set; }
    public string? Notes { get; set; }
    public DateTime ActivityAt { get; set; }
    public DateTime? NextFollowUpAt { get; set; }
    public bool IsCompleted { get; set; } = true;
    public int CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }

    // Joined fields (populated when reading from the today-panel SP)
    public string? LeadNumber { get; set; }
    public string? LeadName { get; set; }
    public string? LeadMobile { get; set; }
    public string? LeadEmail { get; set; }
    public int? AssignedToUserId { get; set; }
    public string? LeadStatusName { get; set; }
    public string? LeadStatusColor { get; set; }

    // Computed for the today panel
    public int DaysOverdue { get; set; }
    public int DaysUntil { get; set; }

    public bool IsScheduledFollowUp => !IsCompleted && NextFollowUpAt.HasValue;
    public bool IsOverdue => IsScheduledFollowUp && NextFollowUpAt < DateTime.UtcNow;
}

public class TodayPanel
{
    public List<LeadActivity> Overdue { get; set; } = [];
    public List<LeadActivity> Today { get; set; } = [];
    public List<LeadActivity> Upcoming { get; set; } = [];
    public int OverdueCount { get; set; }
    public int TodayCount { get; set; }
    public int UpcomingCount { get; set; }

    public int ActionableCount => OverdueCount + TodayCount;
}

public static class ActivityTypes
{
    public const string Call         = "Call";
    public const string Email        = "Email";
    public const string WhatsApp     = "WhatsApp";
    public const string Meeting      = "Meeting";
    public const string Note         = "Note";
    public const string FollowUp     = "FollowUp";       // scheduled future activity
    public const string StatusChange = "StatusChange";   // auto-logged by SP

    public static readonly string[] UserSelectable =
        [Note, Call, Email, WhatsApp, Meeting, FollowUp];

    public static (string icon, string color) Style(string type) => type switch
    {
        Call         => ("bi-telephone-fill",      "success"),
        Email        => ("bi-envelope-fill",       "info"),
        WhatsApp     => ("bi-whatsapp",            "success"),
        Meeting      => ("bi-people-fill",         "primary"),
        Note         => ("bi-sticky-fill",         "warning"),
        FollowUp     => ("bi-bell-fill",           "danger"),
        StatusChange => ("bi-flag-fill",           "secondary"),
        _            => ("bi-circle-fill",         "secondary")
    };
}
