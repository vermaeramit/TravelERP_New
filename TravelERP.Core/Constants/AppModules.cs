namespace TravelERP.Core.Constants;

public static class AppModules
{
    // Operations
    public const string Dashboard = "Dashboard";
    public const string Leads     = "Leads";
    public const string Packages  = "Packages";
    public const string Bookings  = "Bookings";

    // Travel Masters
    public const string Destinations = "Destinations";
    public const string Hotels       = "Hotels";
    public const string RoomTypes    = "RoomTypes";
    public const string MealPlans    = "MealPlans";
    public const string Sightseeings = "Sightseeings";
    public const string Itineraries  = "Itineraries";

    // CRM Masters
    public const string LeadSources       = "LeadSources";
    public const string LeadStatuses      = "LeadStatuses";
    public const string ActivityTemplates = "ActivityTemplates";
    public const string VisaTypes         = "VisaTypes";
    public const string MailTemplates     = "MailTemplates";

    // Finance Masters
    public const string BankAccounts = "BankAccounts";

    // Admin
    public const string Reports = "Reports";
    public const string Roles   = "Roles";

    public static readonly string[] All =
    [
        Dashboard, Leads, Packages, Bookings,
        Destinations, Hotels, RoomTypes, MealPlans, Sightseeings, Itineraries,
        LeadSources, LeadStatuses, ActivityTemplates, VisaTypes, MailTemplates,
        BankAccounts,
        Reports, Roles
    ];

    /// <summary>Modules grouped into sections, for the Roles &amp; Permissions UI.</summary>
    public static readonly (string Section, string[] Modules)[] Sections =
    [
        ("Operations",      [ Dashboard, Leads, Packages, Bookings ]),
        ("Travel Masters",  [ Destinations, Hotels, RoomTypes, MealPlans, Sightseeings, Itineraries ]),
        ("CRM Masters",     [ LeadSources, LeadStatuses, ActivityTemplates, VisaTypes, MailTemplates ]),
        ("Finance Masters", [ BankAccounts ]),
        ("Admin",           [ Reports, Roles ]),
    ];
}
