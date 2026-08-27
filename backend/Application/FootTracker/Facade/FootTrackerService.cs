using ExploreMy.Api.Application.FootTracker.FavouritePlace;
using ExploreMy.Api.Application.FootTracker.Navigation;
using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.Facade;

public class FootTrackerService : IFootTrackerService
{
    private readonly IFavouritePlaceService _favouritePlaceService;
    private readonly INavigationService _navigationService;

    public FootTrackerService(IFavouritePlaceService favouritePlaceService, INavigationService navigationService)
    {
        _favouritePlaceService = favouritePlaceService;
        _navigationService = navigationService;
    }

    public Task<List<FavouritePlaceDto>> GetFavouritePlacesAsync(int userId)
        => _favouritePlaceService.GetFavouritePlacesAsync(userId);

    public Task<FavouritePlaceDto> AddFavouritePlaceAsync(int userId, AddFavouritePlaceRequestDto request)
        => _favouritePlaceService.AddFavouritePlaceAsync(userId, request);

    public Task RemoveFavouritePlacesAsync(int userId, RemoveFavouritePlacesRequestDto request)
        => _favouritePlaceService.RemoveFavouritePlacesAsync(userId, request);

    public Task<RouteResponseDto> GetRouteAsync(RouteRequestDto request)
        => _navigationService.GetRouteAsync(request);
}