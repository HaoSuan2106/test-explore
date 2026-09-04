using ExploreMy.Api.DataAccess.Repositories.FootTracker;
using ExploreMy.Api.DataAccess.Repositories.PlacePhotos;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.ExplorationHistory;

public class ExplorationHistoryService : IExplorationHistoryService
{
    private readonly IFootTrackerRepository _footTrackerRepository;
    private readonly IDistrictLookupService _districtLookupService;
    private readonly IPlacePhotoRepository _photoRepository;

    public ExplorationHistoryService(
        IFootTrackerRepository footTrackerRepository,
        IDistrictLookupService districtLookupService,
        IPlacePhotoRepository photoRepository)
    {
        _footTrackerRepository = footTrackerRepository;
        _districtLookupService = districtLookupService;
        _photoRepository = photoRepository;
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

        var photos = string.IsNullOrEmpty(log.PlaceId)
            ? new Dictionary<string, PlacePhoto>()
            : await _photoRepository.GetByPlaceIdsAsync(new[] { log.PlaceId });

        return MapToDto(log, photos);
    }

    public async Task<List<VisitLogDto>> GetVisitsAsync(int userId)
    {
        var logs = await _footTrackerRepository.GetVisitsByUserIdAsync(userId);

        var placeIds = logs
            .Where(l => !string.IsNullOrEmpty(l.PlaceId))
            .Select(l => l.PlaceId!)
            .Distinct()
            .ToList();

        var photos = await _photoRepository.GetByPlaceIdsAsync(placeIds);

        return logs.Select(l => MapToDto(l, photos)).ToList();
    }

    private static VisitLogDto MapToDto(FootTrackerLog log, IReadOnlyDictionary<string, PlacePhoto> photos)
    {
        PlacePhoto? photo = null;
        if (!string.IsNullOrEmpty(log.PlaceId))
        {
            photos.TryGetValue(log.PlaceId, out photo);
        }

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
            PhotoUrl = photo?.PhotoUrl,
            PhotoAttribution = photo?.Attribution,
        };
    }

    public async Task<Dictionary<string, int>> GetExplorationMapAsync(int userId)
    {
        var visits = await _footTrackerRepository.GetVisitsByUserIdAsync(userId);

        var counts = new Dictionary<string, int>();
        foreach (var visit in visits)
        {
            if (visit.Latitude is null || visit.Longitude is null) continue;

            var district = _districtLookupService.FindDistrict(visit.Latitude.Value, visit.Longitude.Value);
            if (district is null) continue;

            counts[district] = counts.GetValueOrDefault(district) + 1;
        }

        return counts;
    }
}