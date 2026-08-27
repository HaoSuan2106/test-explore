using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.FavouritePlace;

public interface IFavouritePlaceService
{
    Task<List<FavouritePlaceDto>> GetFavouritePlacesAsync(int userId);
    Task<FavouritePlaceDto> AddFavouritePlaceAsync(int userId, AddFavouritePlaceRequestDto request);
    Task RemoveFavouritePlacesAsync(int userId, RemoveFavouritePlacesRequestDto request);
}