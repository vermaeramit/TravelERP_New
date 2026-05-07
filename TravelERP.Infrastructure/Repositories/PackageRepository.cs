using System.Data;
using Dapper;
using TravelERP.Core.Common;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class PackageRepository : IPackageRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;
    private readonly ICompanyRepository _companies;

    public PackageRepository(DbConnectionFactory factory, ITenantContext tenant, ICompanyRepository companies)
    {
        _factory = factory;
        _tenant = tenant;
        _companies = companies;
    }

    public async Task<PagedResult<Package>> GetPagedAsync(string? search, int page, int pageSize)
    {
        using var conn = _factory.CreateMasterConnection();
        var rows = (await conn.QueryAsync<Package>(
            "sp_Package_GetAll",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                Search   = string.IsNullOrWhiteSpace(search) ? null : search.Trim(),
                Page     = page < 1 ? 1 : page,
                PageSize = pageSize is < 5 or > 100 ? 20 : pageSize
            },
            commandType: CommandType.StoredProcedure)).ToList();

        return new PagedResult<Package>
        {
            Items    = rows,
            Page     = page < 1 ? 1 : page,
            PageSize = pageSize is < 5 or > 100 ? 20 : pageSize,
            Total    = rows.FirstOrDefault()?.TotalCount ?? 0
        };
    }

    public async Task<IEnumerable<Package>> GetByLeadAsync(int leadId)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Package>(
            "sp_Package_GetByLead",
            new { DatabaseName = _tenant.DatabaseName, LeadId = leadId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Package?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        using var multi = await conn.QueryMultipleAsync(
            "sp_Package_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);

        var package = await multi.ReadSingleOrDefaultAsync<Package>();
        if (package == null) return null;

        var options = (await multi.ReadAsync<PackageOption>()).ToList();
        var hotels  = (await multi.ReadAsync<PackageOptionHotel>()).ToList();
        foreach (var opt in options)
            opt.Hotels = hotels.Where(h => h.PackageOptionId == opt.Id).ToList();
        package.Options = options;

        var days = (await multi.ReadAsync<PackageDay>()).ToList();
        var dayLinks = (await multi.ReadAsync<dynamic>()).ToList();
        foreach (var d in days)
        {
            var rows = dayLinks.Where(r => (int)r.PackageDayId == d.Id).ToList();
            d.SightseeingIds   = rows.Select(r => (int)r.SightseeingId).ToList();
            d.SightseeingNames = rows.Select(r => (string?)r.SightseeingName ?? "").Where(s => s.Length > 0).ToList();
        }
        package.ItineraryDays = days;

        return package;
    }

    public async Task<(int Id, string PackageNumber)> InsertAsync(Package pkg)
    {
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        using var conn = _factory.CreateMasterConnection();

        var p = new DynamicParameters();
        p.Add("DatabaseName",   _tenant.DatabaseName);
        p.Add("Prefix",         company?.PackagePrefix ?? "PKG");
        p.Add("LeadId",         pkg.LeadId);
        p.Add("Title",          pkg.Title);
        p.Add("DestinationId",  pkg.DestinationId);
        p.Add("CustomerName",   pkg.CustomerName);
        p.Add("CustomerMobile", pkg.CustomerMobile);
        p.Add("CustomerEmail",  pkg.CustomerEmail);
        p.Add("Adults",         pkg.Adults);
        p.Add("Children",       pkg.Children);
        p.Add("Infants",        pkg.Infants);
        p.Add("Days",           pkg.Days);
        p.Add("Nights",         pkg.Nights);
        p.Add("StartDate",      pkg.StartDate, DbType.Date);
        p.Add("PriceMode",      pkg.PriceMode);
        p.Add("Currency",       pkg.Currency);
        p.Add("FlightDetails",  pkg.FlightDetails);
        p.Add("Inclusions",     pkg.Inclusions);
        p.Add("Exclusions",     pkg.Exclusions);
        p.Add("Notes",          pkg.Notes);
        p.Add("CreatedBy",      _tenant.UserId);
        p.Add("NewId",         dbType: DbType.Int32,  direction: ParameterDirection.Output);
        p.Add("PackageNumber", dbType: DbType.String, size: 40, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Package_Insert", p, commandType: CommandType.StoredProcedure);

        var pkgId = p.Get<int>("NewId");
        await SaveOptionsAsync(conn, pkgId, pkg.Options);
        await SaveDaysAsync(conn, pkgId, pkg.ItineraryDays);

        return (pkgId, p.Get<string>("PackageNumber"));
    }

    public async Task UpdateAsync(Package pkg)
    {
        using var conn = _factory.CreateMasterConnection();

        await conn.ExecuteAsync(
            "sp_Package_Update",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                pkg.Id, pkg.Title, pkg.DestinationId,
                pkg.CustomerName, pkg.CustomerMobile, pkg.CustomerEmail,
                pkg.Adults, pkg.Children, pkg.Infants,
                pkg.Days, pkg.Nights, StartDate = pkg.StartDate,
                pkg.PriceMode, pkg.Currency,
                pkg.FlightDetails, pkg.Inclusions, pkg.Exclusions,
                pkg.Notes,
                UpdatedBy = _tenant.UserId
            },
            commandType: CommandType.StoredProcedure);

        await SaveOptionsAsync(conn, pkg.Id, pkg.Options);
        await SaveDaysAsync(conn, pkg.Id, pkg.ItineraryDays);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Package_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    private async Task SaveOptionsAsync(IDbConnection conn, int packageId, IEnumerable<PackageOption> options)
    {
        // Clear existing options + hotels in one go
        await conn.ExecuteAsync(
            "sp_Package_ReplaceOptions",
            new { DatabaseName = _tenant.DatabaseName, PackageId = packageId },
            commandType: CommandType.StoredProcedure);

        int order = 0;
        foreach (var opt in options)
        {
            if (string.IsNullOrWhiteSpace(opt.OptionName)) continue;

            var p = new DynamicParameters();
            p.Add("DatabaseName",  _tenant.DatabaseName);
            p.Add("PackageId",     packageId);
            p.Add("OptionName",    opt.OptionName.Trim());
            p.Add("DisplayOrder",  order);
            p.Add("LandPrice",     opt.LandPrice);
            p.Add("FlightPrice",   opt.FlightPrice);
            p.Add("FinalPrice",    opt.FinalPrice);
            p.Add("IsRecommended", opt.IsRecommended);
            p.Add("Notes",         opt.Notes);
            p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
            await conn.ExecuteAsync("sp_PackageOption_Insert", p, commandType: CommandType.StoredProcedure);
            var optionId = p.Get<int>("NewId");

            int hOrder = 0;
            foreach (var h in opt.Hotels)
            {
                if (h.HotelId == null && h.RoomTypeId == null && h.MealPlanId == null
                    && string.IsNullOrWhiteSpace(h.OtherText)) continue;
                await conn.ExecuteAsync(
                    "sp_PackageOptionHotel_Insert",
                    new
                    {
                        DatabaseName    = _tenant.DatabaseName,
                        PackageOptionId = optionId,
                        DisplayOrder    = hOrder++,
                        h.Nights, h.HotelId, h.RoomTypeId, h.MealPlanId, h.OtherText
                    },
                    commandType: CommandType.StoredProcedure);
            }

            order++;
        }
    }

    private async Task SaveDaysAsync(IDbConnection conn, int packageId, IEnumerable<PackageDay> days)
    {
        await conn.ExecuteAsync(
            "sp_Package_ReplaceDays",
            new { DatabaseName = _tenant.DatabaseName, PackageId = packageId },
            commandType: CommandType.StoredProcedure);

        int dayNum = 1;
        foreach (var d in days)
        {
            if (string.IsNullOrWhiteSpace(d.Title)
                && string.IsNullOrWhiteSpace(d.Description)
                && (d.SightseeingIds == null || d.SightseeingIds.Count == 0))
                continue;

            var p = new DynamicParameters();
            p.Add("DatabaseName", _tenant.DatabaseName);
            p.Add("PackageId",    packageId);
            p.Add("DayNumber",    dayNum);
            p.Add("Title",        string.IsNullOrWhiteSpace(d.Title) ? $"Day {dayNum}" : d.Title.Trim());
            p.Add("Description",  d.Description);
            p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
            await conn.ExecuteAsync("sp_PackageDay_Insert", p, commandType: CommandType.StoredProcedure);
            var dayId = p.Get<int>("NewId");

            if (d.SightseeingIds != null)
            {
                foreach (var sid in d.SightseeingIds.Distinct())
                {
                    if (sid <= 0) continue;
                    await conn.ExecuteAsync(
                        "sp_PackageDaySightseeing_Insert",
                        new { DatabaseName = _tenant.DatabaseName, PackageDayId = dayId, SightseeingId = sid },
                        commandType: CommandType.StoredProcedure);
                }
            }
            dayNum++;
        }
    }
}
