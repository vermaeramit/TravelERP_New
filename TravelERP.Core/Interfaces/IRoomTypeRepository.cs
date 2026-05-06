using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IRoomTypeRepository
{
    Task<IEnumerable<RoomType>> GetAllAsync();
    Task<RoomType?> GetByIdAsync(int id);
    Task<int> InsertAsync(RoomType roomType);
    Task UpdateAsync(RoomType roomType);
    Task DeleteAsync(int id);
}
