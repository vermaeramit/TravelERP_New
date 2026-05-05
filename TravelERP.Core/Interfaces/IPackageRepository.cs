using TravelERP.Core.Entities.Tenant;
using TravelERP.Shared.Enums;

namespace TravelERP.Core.Interfaces;

public interface IPackageRepository
{
    Task<TourPackage?> GetByIdAsync(int id);
    Task<IEnumerable<TourPackage>> GetAllAsync();
    Task<IEnumerable<TourPackage>> GetByTypeAsync(PackageType type);
    Task<IEnumerable<TourPackage>> GetFeaturedAsync();
    Task<IEnumerable<TourPackage>> SearchAsync(string keyword);
    Task<int> InsertAsync(TourPackage package);
    Task<bool> UpdateAsync(TourPackage package);
    Task<bool> DeleteAsync(int id);
    Task<string> GeneratePackageCodeAsync();
}
