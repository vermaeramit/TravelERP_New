using TravelERP.Core.Entities.Master;

namespace TravelERP.Core.Interfaces;

public interface IUserRepository
{
    Task<MasterUser?> GetByIdAsync(int id);
    Task<MasterUser?> GetByEmailAsync(string email);
    Task<IEnumerable<MasterUser>> GetByCompanyAsync(int companyId);
    Task<int> InsertAsync(MasterUser user);
    Task<bool> UpdateAsync(MasterUser user);
    Task<bool> UpdateLastLoginAsync(int userId);
    Task<bool> ChangePasswordAsync(int userId, string passwordHash);
}
