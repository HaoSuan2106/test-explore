using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.Facade;

public interface IFootTrackerService
{
    Task<List<FavouritePlaceDto>> GetFavouritePlacesAsync(int userId);
    Task<FavouritePlaceDto> AddFavouritePlaceAsync(int userId, AddFavouritePlaceRequestDto request);
    Task RemoveFavouritePlacesAsync(int userId, RemoveFavouritePlacesRequestDto request);
    Task<RouteResponseDto> GetRouteAsync(RouteRequestDto request);
    Task<VisitLogDto> RecordVisitAsync(int userId, RecordVisitRequestDto request);
    Task<List<VisitLogDto>> GetVisitsAsync(int userId);
    Task<Dictionary<string, int>> GetExplorationMapAsync(int userId);
}