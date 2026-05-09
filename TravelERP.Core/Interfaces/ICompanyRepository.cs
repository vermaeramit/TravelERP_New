using TravelERP.Core.Entities.Master;

namespace TravelERP.Core.Interfaces;

public interface ICompanyRepository
{
    Task<Company?> GetByIdAsync(int id);
    Task<Company?> GetBySlugAsync(string slug);
    Task<IEnumerable<Company>> GetAllAsync();
    Task<int> InsertAsync(Company company);
    Task<bool> UpdateAsync(Company company);
    Task<bool> UpdateNumberSeriesAsync(int companyId, string leadPrefix, string packagePrefix, string bookingPrefix, string invoicePrefix, int? updatedBy);
    Task<bool> UpdateQuoteBrandingAsync(int companyId, string? greetingParagraph, string? whyBookWithUs, string? logoUrl, bool updateLogo, int? updatedBy);
    Task<bool> UpdateEmailSettingsAsync(int companyId, Company settings, int? updatedBy);
    Task<bool> UpdateVoucherDefaultsAsync(int companyId, Company settings, int? updatedBy);
    Task<bool> ExistsAsync(string slug);
    Task<string> GenerateDbNameAsync();
}
