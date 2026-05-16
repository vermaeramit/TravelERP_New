using TravelERP.Core.Entities.Master;

namespace TravelERP.Core.Interfaces;

public interface ICompanyRepository
{
    Task<Company?> GetByIdAsync(int id);
    Task<Company?> GetBySlugAsync(string slug);
    Task<IEnumerable<Company>> GetAllAsync();
    Task<int> InsertAsync(Company company);
    Task<bool> UpdateAsync(Company company);
    Task<bool> UpdateProfileAsync(Company company, int? updatedBy);
    Task<bool> UpdateNumberSeriesAsync(int companyId, string leadPrefix, string packagePrefix, string bookingPrefix, string invoicePrefix, int? updatedBy);
    Task<bool> UpdateQuoteBrandingAsync(int companyId, string? greetingParagraph, string? whyBookWithUs, string? logoUrl, bool updateLogo, string? googlePlaceId, string? googleApiKey, int? updatedBy);
    Task<bool> UpdateGoogleReviewsCacheAsync(int companyId, string? cacheJson, DateTime? cachedAt);
    Task<bool> UpdateEmailSettingsAsync(int companyId, Company settings, int? updatedBy);
    Task<bool> UpdateVoucherDefaultsAsync(int companyId, Company settings, int? updatedBy);
    Task<bool> ExistsAsync(string slug);
    Task<string> GenerateDbNameAsync();

    // Platform-admin operations
    Task<bool> UpdateStatusAsync(int companyId, TravelERP.Shared.Enums.CompanyStatus status, int? updatedBy);
    Task<bool> UpdateBillingAsync(int companyId, string planName, int maxUsers, DateTime? trialEndsAt, DateTime? subscriptionEndsAt, int? updatedBy);
    Task<bool> SoftDeleteAsync(int companyId, int? updatedBy);
}
