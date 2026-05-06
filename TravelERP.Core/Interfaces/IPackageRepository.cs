using TravelERP.Core.Common;
using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IPackageRepository
{
    Task<PagedResult<Package>> GetPagedAsync(string? search, int page, int pageSize);
    Task<Package?> GetByIdAsync(int id);
    Task<(int Id, string PackageNumber)> InsertAsync(Package package);
    Task UpdateAsync(Package package);
    Task DeleteAsync(int id);
}
