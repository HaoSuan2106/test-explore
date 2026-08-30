using ExploreMy.Api.Application.FootTracker.ExplorationHistory;
using ExploreMy.Api.Application.FootTracker.FavouritePlace;
using ExploreMy.Api.Application.FootTracker.Navigation;
using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.Facade;

public class FootTrackerService : IFootTrackerService
{
    private readonly IFavouritePlaceService _favouritePlaceService;
    private readonly INavigationService _navigationService;
    private readonly IExplorationHistoryService _explorationHistoryService;

    public FootTrackerService(
        IFavouritePlaceService favouritePlaceService,
        INavigationService navigationService,
        IExplorationHistoryService explorationHistoryService)
    {
        _favouritePlaceService = favouritePlaceService;
        _navigationService = navigationService;
        _explorationHistoryService = explorationHistoryService;
    }

    public Task<List<FavouritePlaceDto>> GetFavouritePlacesAsync(int userId) => _favouritePlaceService.GetFavouritePlacesAsync(userId);
    public Task<FavouritePlaceDto> AddFavouritePlaceAsync(int userId, AddFavouritePlaceRequestDto request) => _favouritePlaceService.AddFavouritePlaceAsync(userId, request);
    public Task RemoveFavouritePlacesAsync(int userId, RemoveFavouritePlacesRequestDto request) => _favouritePlaceService.RemoveFavouritePlacesAsync(userId, request);
    public Task<RouteResponseDto> GetRouteAsync(RouteRequestDto request) => _navigationService.GetRouteAsync(request);
    public Task<VisitLogDto> RecordVisitAsync(int userId, RecordVisitRequestDto request) => _explorationHistoryService.RecordVisitAsync(userId, request);
    public Task<List<VisitLogDto>> GetVisitsAsync(int userId) => _explorationHistoryService.GetVisitsAsync(userId);
}