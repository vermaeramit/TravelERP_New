using System.Text.RegularExpressions;
using Dapper;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Web.Services;

public class TenantDbProvisioningService
{
    private readonly DbConnectionFactory _factory;
    private readonly IWebHostEnvironment _env;

    // Matches a line containing only "GO" (case-insensitive), with optional whitespace
    private static readonly Regex GoBatchSplitter =
        new(@"^\s*GO\s*$", RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.Compiled);

    public TenantDbProvisioningService(DbConnectionFactory factory, IWebHostEnvironment env)
    {
        _factory = factory;
        _env = env;
    }

    public async Task ProvisionAsync(string databaseName)
    {
        var isNew = await CreateDatabaseAsync(databaseName);
        if (isNew)
            await RunSchemaAsync(databaseName);
        // All SPs live in master DB — no per-tenant SP provisioning needed
    }

    /// <returns>true if the database was just created, false if it already existed</returns>
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
        // Resolve path relative to the solution root (one level above the web project)
        var schemaPath = Path.GetFullPath(
            Path.Combine(_env.ContentRootPath, "..", "Database", "Tenant", "01_TenantDB_Schema.sql"));

        if (!File.Exists(schemaPath))
            throw new FileNotFoundException($"Tenant schema script not found at: {schemaPath}");

        var script = await File.ReadAllTextAsync(schemaPath);

        // Split on whole-line GO statements only (not on GO inside identifiers/strings)
        var batches = GoBatchSplitter.Split(script);

        using var conn = _factory.CreateTenantConnection(databaseName);

        foreach (var batch in batches)
        {
            var trimmed = batch.Trim();
            if (!string.IsNullOrWhiteSpace(trimmed))
                await conn.ExecuteAsync(trimmed, commandTimeout: 120);
        }
    }
}
