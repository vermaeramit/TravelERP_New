using System.Data;
using Dapper;
using TravelERP.Core.Entities.Master;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class CompanyRepository : ICompanyRepository
{
    private readonly DbConnectionFactory _factory;

    public CompanyRepository(DbConnectionFactory factory) => _factory = factory;

    public async Task<Company?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Company>(
            "sp_Company_GetById", new { Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Company?> GetBySlugAsync(string slug)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Company>(
            "sp_Company_GetBySlug", new { Slug = slug },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<Company>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Company>(
            "sp_Company_GetAll", commandType: CommandType.StoredProcedure);
    }

    public async Task<int> InsertAsync(Company company)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("Name",               company.Name);
        p.Add("Slug",               company.Slug);
        p.Add("DatabaseName",       company.DatabaseName);
        p.Add("Email",              company.Email);
        p.Add("Phone",              company.Phone);
        p.Add("Address",            company.Address);
        p.Add("City",               company.City);
        p.Add("Country",            company.Country);
        p.Add("LogoUrl",            company.LogoUrl);
        p.Add("LicenseNumber",      company.LicenseNumber);
        p.Add("TaxNumber",          company.TaxNumber);
        p.Add("Status",             (byte)company.Status);
        p.Add("TrialEndsAt",        company.TrialEndsAt);
        p.Add("SubscriptionEndsAt", company.SubscriptionEndsAt);
        p.Add("PlanName",           company.PlanName);
        p.Add("MaxUsers",           company.MaxUsers);
        p.Add("TimeZone",           company.TimeZone);
        p.Add("Currency",           company.Currency);
        p.Add("CurrencySymbol",     company.CurrencySymbol);
        p.Add("CreatedAt",          company.CreatedAt);
        p.Add("CreatedBy",          company.CreatedBy);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Company_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task<bool> UpdateAsync(Company company)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_Update", company, commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateProfileAsync(Company c, int? updatedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_UpdateProfile",
            new
            {
                Id             = c.Id,
                c.Name,
                c.Email,
                c.Phone,
                c.Address,
                c.City,
                c.Country,
                c.LicenseNumber,
                c.TaxNumber,
                c.TimeZone,
                c.Currency,
                c.CurrencySymbol,
                UpdatedBy      = updatedBy
            },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateNumberSeriesAsync(int companyId, string leadPrefix, string packagePrefix, string bookingPrefix, string invoicePrefix, int? updatedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_UpdateNumberSeries",
            new
            {
                Id            = companyId,
                LeadPrefix    = string.IsNullOrWhiteSpace(leadPrefix)    ? "LD"  : leadPrefix.Trim().ToUpperInvariant(),
                PackagePrefix = string.IsNullOrWhiteSpace(packagePrefix) ? "PKG" : packagePrefix.Trim().ToUpperInvariant(),
                BookingPrefix = string.IsNullOrWhiteSpace(bookingPrefix) ? "BK"  : bookingPrefix.Trim().ToUpperInvariant(),
                InvoicePrefix = string.IsNullOrWhiteSpace(invoicePrefix) ? "INV" : invoicePrefix.Trim().ToUpperInvariant(),
                UpdatedBy     = updatedBy
            },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateQuoteBrandingAsync(int companyId, string? greetingParagraph, string? whyBookWithUs, string? logoUrl, bool updateLogo, int? updatedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_UpdateQuoteBranding",
            new
            {
                Id                = companyId,
                GreetingParagraph = string.IsNullOrWhiteSpace(greetingParagraph) ? null : greetingParagraph,
                WhyBookWithUs     = string.IsNullOrWhiteSpace(whyBookWithUs)     ? null : whyBookWithUs,
                LogoUrl           = string.IsNullOrWhiteSpace(logoUrl) ? null : logoUrl,
                UpdateLogo        = updateLogo,
                UpdatedBy         = updatedBy
            },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateEmailSettingsAsync(int companyId, Company settings, int? updatedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_UpdateEmailSettings",
            new
            {
                Id            = companyId,
                settings.SmtpHost,
                settings.SmtpPort,
                settings.SmtpUsername,
                settings.SmtpPassword,
                settings.SmtpFromEmail,
                settings.SmtpFromName,
                settings.SmtpUseTls,
                UpdatedBy     = updatedBy
            },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateVoucherDefaultsAsync(int companyId, Company settings, int? updatedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_UpdateVoucherDefaults",
            new
            {
                Id                  = companyId,
                settings.VoucherCheckInTime,
                settings.VoucherCheckOutTime,
                settings.VoucherHotelNote,
                settings.VoucherPolicyHtml,
                UpdatedBy           = updatedBy
            },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> ExistsAsync(string slug)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteScalarAsync<int>(
            "sp_Company_ExistsBySlug", new { Slug = slug },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<string> GenerateDbNameAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", dbType: DbType.String, size: 100, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Company_GenerateDbName", p, commandType: CommandType.StoredProcedure);
        return p.Get<string>("DatabaseName");
    }

    public async Task<bool> UpdateStatusAsync(int companyId, TravelERP.Shared.Enums.CompanyStatus status, int? updatedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_UpdateStatus",
            new { Id = companyId, Status = (byte)status, UpdatedBy = updatedBy },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> UpdateBillingAsync(int companyId, string planName, int maxUsers,
        DateTime? trialEndsAt, DateTime? subscriptionEndsAt, int? updatedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_UpdateBilling",
            new
            {
                Id                 = companyId,
                PlanName           = planName,
                MaxUsers           = maxUsers,
                TrialEndsAt        = trialEndsAt,
                SubscriptionEndsAt = subscriptionEndsAt,
                UpdatedBy          = updatedBy
            },
            commandType: CommandType.StoredProcedure) > 0;
    }

    public async Task<bool> SoftDeleteAsync(int companyId, int? updatedBy)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_Company_SoftDelete",
            new { Id = companyId, UpdatedBy = updatedBy },
            commandType: CommandType.StoredProcedure) > 0;
    }
}
