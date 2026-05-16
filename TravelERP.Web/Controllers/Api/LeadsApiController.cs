using System.ComponentModel.DataAnnotations;
using System.Data;
using Dapper;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Master;
using TravelERP.Infrastructure.Data;
using TravelERP.Web.Services;

namespace TravelERP.Web.Controllers.Api;

/// <summary>
/// Public lead-intake API. Authenticated by per-tenant API keys via <c>X-Api-Key</c> header.
/// </summary>
[ApiController]
[Route("api/v1/leads")]
[ApiKeyAuth]
public class LeadsApiController : ControllerBase
{
    private readonly DbConnectionFactory _factory;

    public LeadsApiController(DbConnectionFactory factory) => _factory = factory;

    /// <summary>Create a new lead in the calling tenant's CRM.</summary>
    [HttpPost("")]
    public async Task<IActionResult> Create([FromBody] CreateLeadRequest body)
    {
        if (body == null) return BadRequest(new { error = "Body is required." });
        if (string.IsNullOrWhiteSpace(body.Name))
            return BadRequest(new { error = "Name is required." });

        var key = (ApiKey)HttpContext.Items[ApiKeyAuthAttribute.ItemKey]!;
        if (string.IsNullOrWhiteSpace(key.DatabaseName))
            return StatusCode(500, new { error = "Tenant database not resolved." });

        // Resolve Source/Destination by name when ID isn't provided (best-effort, optional).
        int? sourceId      = body.SourceId      ?? await LookupIdAsync(key.DatabaseName!, "LeadSources",  body.SourceName);
        int? destinationId = body.DestinationId ?? await LookupIdAsync(key.DatabaseName!, "Destinations", body.DestinationName);

        using var conn = _factory.CreateMasterConnection();
        var p = new DynamicParameters();
        p.Add("DatabaseName",     key.DatabaseName);
        p.Add("Prefix",           string.IsNullOrWhiteSpace(key.LeadPrefix) ? "LD" : key.LeadPrefix);
        p.Add("StatusId",         body.StatusId);
        p.Add("SourceId",         sourceId);
        p.Add("AssignedToUserId", body.AssignedToUserId);
        p.Add("DestinationId",    destinationId);
        p.Add("Name",             body.Name.Trim());
        p.Add("Mobile",           body.Mobile);
        p.Add("Email",            body.Email);
        p.Add("TravelingDate",    body.TravelingDate);
        p.Add("LeavingFrom",      body.LeavingFrom);
        p.Add("HotelRecommended", body.HotelRecommended);
        p.Add("Adults",           body.Adults);
        p.Add("Children",         body.Children);
        p.Add("Infants",          body.Infants);
        p.Add("Days",             body.Days);
        p.Add("Remark",           body.Remark);
        p.Add("CreatedBy",        0);  // API system user
        p.Add("NewId",      dbType: DbType.Int32,  direction: ParameterDirection.Output);
        p.Add("LeadNumber", dbType: DbType.String, size: 30, direction: ParameterDirection.Output);

        try
        {
            await conn.ExecuteAsync("sp_Lead_Insert", p, commandType: CommandType.StoredProcedure);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Failed to create lead.", detail = ex.Message });
        }

        return CreatedAtAction(nameof(Create), new
        {
            id         = p.Get<int>("NewId"),
            leadNumber = p.Get<string>("LeadNumber"),
            companyId  = key.CompanyId,
            createdAt  = DateTime.UtcNow
        });
    }

    /// <summary>Look up the Id of a tenant-side row by Name (LeadSources or Destinations).</summary>
    private async Task<int?> LookupIdAsync(string databaseName, string table, string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return null;
        using var conn = _factory.CreateMasterConnection();
        var sql = $"SELECT TOP 1 Id FROM [{databaseName}].dbo.{table} WHERE Name = @Name AND IsActive = 1";
        return await conn.QuerySingleOrDefaultAsync<int?>(sql, new { Name = name.Trim() });
    }

    public class CreateLeadRequest
    {
        [Required, StringLength(150)]
        public string Name { get; set; } = string.Empty;

        [StringLength(30)]   public string? Mobile { get; set; }
        [EmailAddress, StringLength(150)] public string? Email  { get; set; }

        // Either pass the FK id directly, or pass a name and we'll look it up.
        public int?    SourceId        { get; set; }
        public string? SourceName      { get; set; }
        public int?    DestinationId   { get; set; }
        public string? DestinationName { get; set; }
        public int?    StatusId        { get; set; }
        public int?    AssignedToUserId { get; set; }

        public DateTime? TravelingDate { get; set; }
        [StringLength(150)] public string? LeavingFrom { get; set; }
        [StringLength(200)] public string? HotelRecommended { get; set; }
        public int Adults   { get; set; } = 1;
        public int Children { get; set; }
        public int Infants  { get; set; }
        public int? Days    { get; set; }
        public string? Remark { get; set; }
    }
}
