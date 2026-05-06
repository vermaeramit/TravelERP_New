using TravelERP.Core.Common;
using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface ILeadRepository
{
    Task<PagedResult<Lead>> GetPagedAsync(LeadFilter filter);
    Task<Lead?> GetByIdAsync(int id);
    Task<(int Id, string LeadNumber)> InsertAsync(Lead lead);
    Task UpdateAsync(Lead lead);
    Task ChangeStatusAsync(int id, int statusId);
    Task DeleteAsync(int id);
}

public class LeadFilter
{
    public int? StatusId { get; set; }
    public int? SourceId { get; set; }
    public int? AssignedTo { get; set; }
    public int? DestinationId { get; set; }
    public DateTime? DateFrom { get; set; }
    public DateTime? DateTo { get; set; }
    public string? Search { get; set; }
    public bool ShowClosed { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}
