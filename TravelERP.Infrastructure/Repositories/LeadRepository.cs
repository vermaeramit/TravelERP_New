using System.Data;
using Dapper;
using TravelERP.Core.Common;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class LeadRepository : ILeadRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;
    private readonly ICompanyRepository _companies;

    public LeadRepository(DbConnectionFactory factory, ITenantContext tenant, ICompanyRepository companies)
    {
        _factory = factory;
        _tenant = tenant;
        _companies = companies;
    }

    public async Task<PagedResult<Lead>> GetPagedAsync(LeadFilter f)
    {
        using var conn = _factory.CreateMasterConnection();
        var rows = (await conn.QueryAsync<Lead>(
            "sp_Lead_GetAll",
            new
            {
                DatabaseName  = _tenant.DatabaseName,
                f.StatusId,
                f.SourceId,
                f.AssignedTo,
                f.DestinationId,
                DateFrom      = f.DateFrom?.Date,
                DateTo        = f.DateTo?.Date,
                f.Search,
                f.ShowClosed,
                f.Page,
                f.PageSize
            },
            commandType: CommandType.StoredProcedure)).ToList();

        return new PagedResult<Lead>
        {
            Items    = rows,
            Page     = f.Page,
            PageSize = f.PageSize,
            Total    = rows.FirstOrDefault()?.TotalCount ?? 0
        };
    }

    public async Task<Lead?> GetByIdAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QuerySingleOrDefaultAsync<Lead>(
            "sp_Lead_GetById",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<(int Id, string LeadNumber)> InsertAsync(Lead l)
    {
        using var conn = _factory.CreateMasterConnection();
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        var p = new DynamicParameters();
        p.Add("DatabaseName",     _tenant.DatabaseName);
        p.Add("Prefix",           company?.LeadPrefix ?? "LD");
        p.Add("StatusId",         l.StatusId);
        p.Add("SourceId",         l.SourceId);
        p.Add("AssignedToUserId", l.AssignedToUserId);
        p.Add("DestinationId",    l.DestinationId);
        p.Add("Name",             l.Name);
        p.Add("Mobile",           l.Mobile);
        p.Add("Email",            l.Email);
        p.Add("TravelingDate",    l.TravelingDate, DbType.Date);
        p.Add("LeavingFrom",      l.LeavingFrom);
        p.Add("HotelRecommended", l.HotelRecommended);
        p.Add("Adults",           l.Adults);
        p.Add("Children",         l.Children);
        p.Add("Infants",          l.Infants);
        p.Add("Days",             l.Days);
        p.Add("Remark",           l.Remark);
        p.Add("CreatedBy",        _tenant.UserId);
        p.Add("NewId",      dbType: DbType.Int32,  direction: ParameterDirection.Output);
        p.Add("LeadNumber", dbType: DbType.String, size: 30, direction: ParameterDirection.Output);
        await conn.ExecuteAsync("sp_Lead_Insert", p, commandType: CommandType.StoredProcedure);
        return (p.Get<int>("NewId"), p.Get<string>("LeadNumber"));
    }

    public async Task UpdateAsync(Lead l)
    {
        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",     _tenant.DatabaseName);
        p.Add("Id",               l.Id);
        p.Add("StatusId",         l.StatusId);
        p.Add("SourceId",         l.SourceId);
        p.Add("AssignedToUserId", l.AssignedToUserId);
        p.Add("DestinationId",    l.DestinationId);
        p.Add("Name",             l.Name);
        p.Add("Mobile",           l.Mobile);
        p.Add("Email",            l.Email);
        p.Add("TravelingDate",    l.TravelingDate, DbType.Date);
        p.Add("LeavingFrom",      l.LeavingFrom);
        p.Add("HotelRecommended", l.HotelRecommended);
        p.Add("Adults",           l.Adults);
        p.Add("Children",         l.Children);
        p.Add("Infants",          l.Infants);
        p.Add("Days",             l.Days);
        p.Add("Remark",           l.Remark);
        p.Add("UpdatedBy",        _tenant.UserId);
        await conn.ExecuteAsync("sp_Lead_Update", p, commandType: CommandType.StoredProcedure);
    }

    public async Task ChangeStatusAsync(int id, int statusId)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Lead_ChangeStatus",
            new { DatabaseName = _tenant.DatabaseName, Id = id, StatusId = statusId, UpdatedBy = _tenant.UserId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(int id)
    {
        using var conn = _factory.CreateMasterConnection();
        await conn.ExecuteAsync(
            "sp_Lead_Delete",
            new { DatabaseName = _tenant.DatabaseName, Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
