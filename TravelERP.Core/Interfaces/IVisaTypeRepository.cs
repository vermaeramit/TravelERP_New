using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IVisaTypeRepository
{
    Task<IEnumerable<VisaType>> GetAllAsync();
    Task<int> InsertAsync(VisaType visaType);
    Task UpdateAsync(VisaType visaType);
    Task DeleteAsync(int id);
}
