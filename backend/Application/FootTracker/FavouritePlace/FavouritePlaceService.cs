using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.Repositories.FootTracker;
using ExploreMy.Api.DTOs.FootTracker;
using DomainFavouritePlace = ExploreMy.Api.Domain.Entities.FavouritePlace;

namespace ExploreMy.Api.Application.FootTracker.FavouritePlace;

public class FavouritePlaceService : IFavouritePlaceService
{
    private readonly IFootTrackerRepository _repository;
    private readonly ILogger<FavouritePlaceService> _logger;

    public FavouritePlaceService(IFootTrackerRepository repository, ILogger<FavouritePlaceService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<List<FavouritePlaceDto>> GetFavouritePlacesAsync(int userId)
    {
        var places = await _repository.GetFavouritePlacesByUserIdAsync(userId);
        return places.Select(ToDto).ToList();
    }

    public async Task<FavouritePlaceDto> AddFavouritePlaceAsync(int userId, AddFavouritePlaceRequestDto request)
    {
        var existing = await _repository.GetFavouritePlaceByUserAndPlaceIdAsync(userId, request.PlaceId);
        if (existing is not null)
        {
            _logger.LogWarning("Add favourite place failed for user {UserId}: place {PlaceId} is already favourited.", userId, request.PlaceId);
            throw new ConflictException("This place is already in your favourites.");
        }

        var favouritePlace = new DomainFavouritePlace
        {
            UserId = userId,
            PlaceId = request.PlaceId,
            Name = request.Name,
            PrimaryType = request.PrimaryType,
            Address = request.Address,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            CreatedAt = DateTime.UtcNow
        };

        await _repository.AddFavouritePlaceAsync(favouritePlace);
        return ToDto(favouritePlace);
    }

    public async Task RemoveFavouritePlacesAsync(int userId, RemoveFavouritePlacesRequestDto request)
    {
        await _repository.RemoveFavouritePlacesAsync(userId, request.FavouritePlaceIds);
    }

    private static FavouritePlaceDto ToDto(DomainFavouritePlace place)
    {
        return new FavouritePlaceDto
        {
            FavouritePlaceId = place.FavouritePlaceId,
            PlaceId = place.PlaceId,
            Name = place.Name,
            PrimaryType = place.PrimaryType,
            Address = place.Address,
            Latitude = place.Latitude,
            Longitude = place.Longitude,
            LastVisitAt = place.LastVisitAt,
            CreatedAt = place.CreatedAt
        };
    }
}