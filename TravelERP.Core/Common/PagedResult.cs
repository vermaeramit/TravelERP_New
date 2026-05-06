namespace TravelERP.Core.Common;

public class PagedResult<T>
{
    public IEnumerable<T> Items { get; init; } = [];
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int Total { get; init; }

    public int TotalPages => PageSize == 0 ? 0 : (int)Math.Ceiling((double)Total / PageSize);
    public int FirstItemNumber => Total == 0 ? 0 : ((Page - 1) * PageSize) + 1;
    public int LastItemNumber  => Math.Min(Page * PageSize, Total);
    public bool HasPrevious => Page > 1;
    public bool HasNext     => Page < TotalPages;
}
