using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.ExplorationHistory;

public interface IExplorationHistoryService
{
    Task<VisitLogDto> RecordVisitAsync(int userId, RecordVisitRequestDto request);
    Task<List<VisitLogDto>> GetVisitsAsync(int userId);
    Task<Dictionary<string, int>> GetExplorationMapAsync(int userId);
}