using TravelERP.Core.Entities.Tenant;

namespace TravelERP.Core.Interfaces;

public interface IMealPlanRepository
{
    Task<IEnumerable<MealPlan>> GetAllAsync();
    Task<int> InsertAsync(MealPlan mealPlan);
    Task UpdateAsync(MealPlan mealPlan);
    Task DeleteAsync(int id);
}
