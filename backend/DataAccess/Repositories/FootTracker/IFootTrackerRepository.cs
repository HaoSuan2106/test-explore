using ExploreMy.Api.Domain.Entities;
using DomainHiddenPlace = ExploreMy.Api.Domain.Entities.HiddenPlace;
namespace ExploreMy.Api.DataAccess.Repositories.FootTracker;

public interface IFootTrackerRepository
{
    Task<List<FavouritePlace>> GetFavouritePlacesByUserIdAsync(int userId);
    Task<FavouritePlace?> GetFavouritePlaceByUserAndPlaceIdAsync(int userId, string placeId);
    Task AddFavouritePlaceAsync(FavouritePlace favouritePlace);
    Task RemoveFavouritePlacesAsync(int userId, List<int> favouritePlaceIds);
    Task AddFootTrackerLogAsync(FootTrackerLog log);
    Task<List<FootTrackerLog>> GetVisitsByUserIdAsync(int userId);
    Task<DomainHiddenPlace?> GetLatestHiddenPlaceCacheByPlaceIdAsync(string placeId);
    Task<Place?> GetPlaceByIdAsync(string placeId);
    Task AddPlaceAsync(Place place);
    Task UpdatePlaceAsync(Place place);
}