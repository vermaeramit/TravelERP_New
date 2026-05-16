using Dapper;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Web.Services;

/// <summary>
/// Idempotent startup seed: ensures a system "Platform" company and the bootstrap
/// admin@platform user exist so a platform super-admin can log in on a fresh install.
/// </summary>
public class PlatformSeedService
{
    private const string PlatformSlug = "platform";
    private const string AdminEmail   = "admin@platform";
    private const string AdminPassword = "Admin@123";   // default — change after first login

    private readonly DbConnectionFactory _factory;
    private readonly ILogger<PlatformSeedService> _log;

    public PlatformSeedService(DbConnectionFactory factory, ILogger<PlatformSeedService> log)
    {
        _factory = factory;
        _log = log;
    }

    public async Task EnsureAsync()
    {
        using var conn = _factory.CreateMasterConnection();

        var companyId = await conn.QuerySingleOrDefaultAsync<int?>(
            "SELECT Id FROM Companies WHERE Slug = @Slug", new { Slug = PlatformSlug });

        if (!companyId.HasValue)
        {
            // Status=0 (Active), Country/Email/Phone are NOT NULL — use placeholders.
            companyId = await conn.ExecuteScalarAsync<int>(@"
                INSERT INTO Companies
                    (Name, Slug, DatabaseName, Email, Phone, Country, Status, TrialEndsAt,
                     PlanName, MaxUsers, TimeZone, Currency, CurrencySymbol, CreatedAt)
                OUTPUT INSERTED.Id
                VALUES
                    ('Platform Admin', @Slug, 'SystemAdmin', @Email, '-', '-', 0,
                     DATEADD(YEAR, 10, GETUTCDATE()),
                     'Internal', 1, 'UTC', 'USD', '$', GETUTCDATE());",
                new { Slug = PlatformSlug, Email = AdminEmail });

            _log.LogInformation("Seeded Platform company (Id={Id})", companyId);
        }

        var existingUser = await conn.QuerySingleOrDefaultAsync<int?>(
            "SELECT Id FROM MasterUsers WHERE Email = @Email", new { Email = AdminEmail });

        if (!existingUser.HasValue)
        {
            var hash = BCrypt.Net.BCrypt.HashPassword(AdminPassword);
            await conn.ExecuteAsync(@"
                INSERT INTO MasterUsers
                    (CompanyId, FullName, Email, PasswordHash, Role, IsActive, CreatedAt, IsDeleted)
                VALUES
                    (@CompanyId, 'Platform Admin', @Email, @Hash, 0, 1, GETUTCDATE(), 0);",
                new { CompanyId = companyId, Email = AdminEmail, Hash = hash });

            _log.LogWarning("Seeded platform super-admin {Email} with default password — CHANGE IT.", AdminEmail);
        }
    }
}
