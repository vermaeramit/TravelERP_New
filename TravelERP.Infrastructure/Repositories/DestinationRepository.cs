using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class DestinationRepository : IDestinationRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public DestinationRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<IEnumerable<Destination>> GetAllAsync()
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<Destination>(
            "sp_Destination_GetAll",
            new { DatabaseName = _tenant.DatabaseName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<Destination?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        using var multi = await conn.QueryMultipleAsync(
            "sp_Destination_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);

        var destination = await multi.ReadSingleOrDefaultAsync<Destination>();
        if (destination == null) return null;
        destination.Reviews = (await multi.ReadAsync<DestinationReview>()).ToList();
        return destination;
    }

    public async Task<int> InsertAsync(Destination destination)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("Name",         destination.Name);
        p.Add("ImageUrl",     destination.ImageUrl);
        p.Add("PackageTerms", destination.PackageTerms);
        p.Add("InvoiceTerms", destination.InvoiceTerms);
        p.Add("CreatedBy",    _tenant.UserId);
        p.Add("NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Destination_Insert", p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("NewId");
    }

    public async Task UpdateAsync(Destination destination)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName", _tenant.DatabaseName);
        p.Add("Id",           destination.Id);
        p.Add("Name",         destination.Name);
        p.Add("ImageUrl",     destination.ImageUrl);
        p.Add("PackageTerms", destination.PackageTerms);
        p.Add("InvoiceTerms", destination.InvoiceTerms);
        p.Add("UpdatedBy",    _tenant.UserId);
        await conn.ExecuteAsync("sp_Destination_Update", p, commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Destination_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task ReplaceReviewsAsync(int destinationId, IEnumerable<DestinationReview> reviews)
    {
        using var conn = _factory.CreateMasterConnection();

        await conn.ExecuteAsync(
            "sp_DestinationReview_DeleteByDestination",
            new { DatabaseName = _tenant.DatabaseName, DestinationId = destinationId },
            commandType: CommandType.StoredProcedure);

        int order = 0;
        foreach (var r in reviews)
        {
            if (string.IsNullOrWhiteSpace(r.TravelerName)) continue;
            await conn.ExecuteAsync(
                "sp_DestinationReview_Insert",
                new
                {
                    DatabaseName  = _tenant.DatabaseName,
                    DestinationId = destinationId,
                    r.TravelerName,
                    r.ImageUrl,
                    r.ReviewText,
                    DisplayOrder  = order++
                },
                commandType: CommandType.StoredProcedure);
        }
    }
}
