using System.Data;
using System.Text.RegularExpressions;
using Dapper;
using TravelERP.Core.Constants;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Web.Services;

public class TenantDbProvisioningService
{
    private readonly DbConnectionFactory _factory;
    private readonly IWebHostEnvironment _env;

    private static readonly Regex GoBatchSplitter =
        new(@"^\s*GO\s*$", RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.Compiled);

    public TenantDbProvisioningService(DbConnectionFactory factory, IWebHostEnvironment env)
    {
        _factory = factory;
        _env = env;
    }

    // Returns the SuperAdmin role ID (to assign to the registering admin user)
    public async Task<int> ProvisionAsync(string databaseName)
    {
        var isNew = await CreateDatabaseAsync(databaseName);
        if (isNew)
            await RunSchemaAsync(databaseName);
        await SeedDefaultLeadStatusesAsync(databaseName);
        await SeedDefaultActivityTemplatesAsync(databaseName);
        return await SeedDefaultRolesAsync(databaseName);
    }

    private async Task<bool> CreateDatabaseAsync(string databaseName)
    {
        using var conn = _factory.CreateServerConnection();
        var exists = await conn.ExecuteScalarAsync<int>(
            "SELECT COUNT(1) FROM sys.databases WHERE name = @Name",
            new { Name = databaseName });
        if (exists > 0) return false;
        await conn.ExecuteAsync($"CREATE DATABASE [{databaseName}]", commandTimeout: 60);
        return true;
    }

    private async Task RunSchemaAsync(string databaseName)
    {
        var schemaPath = Path.GetFullPath(
            Path.Combine(_env.ContentRootPath, "..", "Database", "Tenant", "01_TenantDB_Schema.sql"));
        if (!File.Exists(schemaPath))
            throw new FileNotFoundException($"Tenant schema script not found at: {schemaPath}");

        var script = await File.ReadAllTextAsync(schemaPath);
        var batches = GoBatchSplitter.Split(script);
        using var conn = _factory.CreateTenantConnection(databaseName);
        foreach (var batch in batches)
        {
            var trimmed = batch.Trim();
            if (!string.IsNullOrWhiteSpace(trimmed))
                await conn.ExecuteAsync(trimmed, commandTimeout: 120);
        }
    }

    private async Task<int> SeedDefaultRolesAsync(string databaseName)
    {
        using var conn = _factory.CreateTenantConnection(databaseName);

        // Check if roles already seeded
        var existing = await conn.ExecuteScalarAsync<int>("SELECT COUNT(1) FROM Roles");
        if (existing > 0)
        {
            // Return existing SuperAdmin role ID
            return await conn.ExecuteScalarAsync<int>(
                "SELECT TOP 1 Id FROM Roles WHERE IsSystem = 1");
        }

        // ── Insert default roles ──────────────────────────────────────────
        var superAdminId = await InsertRole(conn, "SuperAdmin", "Full access — non-editable", isSystem: true);
        var adminId      = await InsertRole(conn, "Admin",      "Company administrator", isSystem: false);
        var agentId      = await InsertRole(conn, "Sales Agent","Handles leads and bookings", isSystem: false);
        var acctId       = await InsertRole(conn, "Accountant", "Finance and invoice management", isSystem: false);

        // ── Admin: full access on everything ─────────────────────────────
        foreach (var m in AppModules.All)
            await InsertPerm(conn, adminId, m, v: true, a: true, e: true, d: true);

        // ── Sales Agent permissions ────────────────────────────────────────
        await InsertPerm(conn, agentId, AppModules.Dashboard,  v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, agentId, AppModules.Leads,      v: true,  a: true,  e: true,  d: false);
        await InsertPerm(conn, agentId, AppModules.Customers,  v: true,  a: true,  e: true,  d: false);
        await InsertPerm(conn, agentId, AppModules.Bookings,   v: true,  a: true,  e: true,  d: false);
        await InsertPerm(conn, agentId, AppModules.Packages,   v: true,  a: true,  e: true,  d: false);
        await InsertPerm(conn, agentId, AppModules.Finance,    v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, agentId, AppModules.HR,         v: false, a: false, e: false, d: false);
        await InsertPerm(conn, agentId, AppModules.Visa,       v: true,  a: true,  e: true,  d: false);
        await InsertPerm(conn, agentId, AppModules.Suppliers,  v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, agentId, AppModules.Reports,    v: false, a: false, e: false, d: false);
        await InsertPerm(conn, agentId, AppModules.Masters,    v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, agentId, AppModules.Roles,      v: false, a: false, e: false, d: false);
        await InsertPerm(conn, agentId, AppModules.Settings,   v: false, a: false, e: false, d: false);

        // ── Accountant permissions ─────────────────────────────────────────
        await InsertPerm(conn, acctId, AppModules.Dashboard,  v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Leads,      v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Customers,  v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Bookings,   v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Packages,   v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Finance,    v: true,  a: true,  e: true,  d: false);
        await InsertPerm(conn, acctId, AppModules.HR,         v: false, a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Visa,       v: false, a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Suppliers,  v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Reports,    v: true,  a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Masters,    v: false, a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Roles,      v: false, a: false, e: false, d: false);
        await InsertPerm(conn, acctId, AppModules.Settings,   v: false, a: false, e: false, d: false);

        return superAdminId;
    }

    private static async Task<int> InsertRole(IDbConnection conn, string name, string desc, bool isSystem)
    {
        return await conn.ExecuteScalarAsync<int>(
            @"INSERT INTO Roles (RoleName, Description, IsSystem, IsActive, CreatedAt, CreatedBy)
              VALUES (@Name, @Desc, @IsSystem, 1, GETUTCDATE(), 0);
              SELECT SCOPE_IDENTITY();",
            new { Name = name, Desc = desc, IsSystem = isSystem });
    }

    private static async Task InsertPerm(IDbConnection conn, int roleId, string module,
        bool v, bool a, bool e, bool d)
    {
        await conn.ExecuteAsync(
            @"INSERT INTO RolePermissions (RoleId, Module, CanView, CanAdd, CanEdit, CanDelete)
              VALUES (@RoleId, @Module, @V, @A, @E, @D)",
            new { RoleId = roleId, Module = module, V = v, A = a, E = e, D = d });
    }

    private async Task SeedDefaultLeadStatusesAsync(string databaseName)
    {
        using var conn = _factory.CreateTenantConnection(databaseName);
        var existing = await conn.ExecuteScalarAsync<int>("SELECT COUNT(1) FROM LeadStatuses");
        if (existing > 0) return;

        var defaults = new[]
        {
            ("New",       "primary",   1, true,  false),
            ("Contacted", "info",      2, false, false),
            ("Quoted",    "warning",   3, false, false),
            ("Converted", "success",   4, false, true),
            ("Lost",      "secondary", 5, false, true),
        };

        foreach (var (name, color, order, isDefault, isClosed) in defaults)
        {
            await conn.ExecuteAsync(
                @"INSERT INTO LeadStatuses (Name, Color, DisplayOrder, IsDefault, IsClosed, IsActive, CreatedAt, CreatedBy)
                  VALUES (@Name, @Color, @Order, @IsDefault, @IsClosed, 1, GETUTCDATE(), 0)",
                new { Name = name, Color = color, Order = order, IsDefault = isDefault, IsClosed = isClosed });
        }
    }

    private async Task SeedDefaultActivityTemplatesAsync(string databaseName)
    {
        using var conn = _factory.CreateTenantConnection(databaseName);
        var existing = await conn.ExecuteScalarAsync<int>("SELECT COUNT(1) FROM ActivityTemplates");
        if (existing > 0) return;

        // (Name, ActivityType, Subject, Notes, DisplayOrder)
        var defaults = new[]
        {
            ("Not picking up",            "Call",     "Customer not reachable",     "Tried calling, customer didn't pick up. Will try again later.", 1),
            ("Asked to call back later",  "Call",     "Will call back",             "Customer is busy right now, asked to call back later.",          2),
            ("Customer interested",       "Call",     "Interested",                 "Customer showed interest, awaiting confirmation.",               3),
            ("Customer not interested",   "Call",     "Not interested",             "Customer is not interested at this time.",                       4),
            ("Wrong number",              "Call",     "Wrong number",               "Number provided is not in service / wrong contact.",             5),
            ("Sent quotation",            "Email",    "Quotation sent",             "Quotation emailed to the customer. Awaiting response.",          10),
            ("Sent itinerary",            "WhatsApp", "Itinerary shared on WhatsApp","Detailed itinerary shared on WhatsApp.",                         11),
            ("Customer confirmed",        "Note",     "Booking confirmed",          "Customer confirmed booking. Proceeding with booking creation.",  20),
            ("Already booked elsewhere",  "Note",     "Booked with competitor",     "Customer has already booked through another agency.",            21),
            ("Schedule follow-up",        "FollowUp", "Follow-up call",             "Schedule a follow-up to check on the customer's decision.",      30),
        };

        foreach (var (name, type, subject, notes, order) in defaults)
        {
            await conn.ExecuteAsync(
                @"INSERT INTO ActivityTemplates (Name, ActivityType, Subject, Notes, DisplayOrder, IsActive, CreatedAt, CreatedBy)
                  VALUES (@Name, @Type, @Subject, @Notes, @Order, 1, GETUTCDATE(), 0)",
                new { Name = name, Type = type, Subject = subject, Notes = notes, Order = order });
        }
    }
}
