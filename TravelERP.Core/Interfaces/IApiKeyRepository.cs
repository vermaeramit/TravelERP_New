using TravelERP.Core.Entities.Master;

namespace TravelERP.Core.Interfaces;

public interface IApiKeyRepository
{
    Task<IEnumerable<ApiKey>> GetByCompanyAsync(int companyId);
    Task<ApiKey?> GetByKeyAsync(string apiKey);
    Task<int> InsertAsync(ApiKey key);
    Task RevokeAsync(int id, int companyId);
    Task MarkUsedAsync(int id);
}
