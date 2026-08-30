using ExploreMy.Api.DataAccess.Repositories.FootTracker;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.ExplorationHistory;

public class ExplorationHistoryService : IExplorationHistoryService
{
    private readonly IFootTrackerRepository _footTrackerRepository;

    public ExplorationHistoryService(IFootTrackerRepository footTrackerRepository)
    {
        _footTrackerRepository = footTrackerRepository;
    }

    public async Task<VisitLogDto> RecordVisitAsync(int userId, RecordVisitRequestDto request)
    {
        var log = new FootTrackerLog
        {
            LogId = Guid.NewGuid().ToString(),
            UserId = userId,
            PlaceId = request.PlaceId,
            Title = request.Title,
            PrimaryType = request.PrimaryType,
            Address = request.Address,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            DistanceKm = request.DistanceKm.HasValue ? (decimal)request.DistanceKm.Value : null,
            StartedAt = request.StartedAt,
            EndedAt = request.EndedAt,
            Status = FootTrackerLogStatus.Completed,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };

        await _footTrackerRepository.AddFootTrackerLogAsync(log);

        return MapToDto(log);
    }

    public async Task<List<VisitLogDto>> GetVisitsAsync(int userId)
    {
        var logs = await _footTrackerRepository.GetVisitsByUserIdAsync(userId);
        return logs.Select(MapToDto).ToList();
    }

    private static VisitLogDto MapToDto(FootTrackerLog log)
    {
        return new VisitLogDto
        {
            LogId = log.LogId,
            PlaceId = log.PlaceId,
            Title = log.Title,
            PrimaryType = log.PrimaryType,
            Address = log.Address,
            Latitude = log.Latitude,
            Longitude = log.Longitude,
            DistanceKm = (double?)log.DistanceKm,
            StartedAt = log.StartedAt,
            EndedAt = log.EndedAt,
            Status = log.Status,
        };
    }
}