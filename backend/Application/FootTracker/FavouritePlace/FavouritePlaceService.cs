using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.Repositories.FootTracker;
using ExploreMy.Api.DataAccess.Repositories.PlacePhotos;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.FootTracker;
using DomainFavouritePlace = ExploreMy.Api.Domain.Entities.FavouritePlace;
using DomainPlace = ExploreMy.Api.Domain.Entities.Place;

namespace ExploreMy.Api.Application.FootTracker.FavouritePlace;

public class FavouritePlaceService : IFavouritePlaceService
{
    private readonly IFootTrackerRepository _repository;
    private readonly IPlacePhotoRepository _photoRepository;
    private readonly ILogger<FavouritePlaceService> _logger;

    public FavouritePlaceService(
        IFootTrackerRepository repository,
        IPlacePhotoRepository photoRepository,
        ILogger<FavouritePlaceService> logger)
    {
        _repository = repository;
        _photoRepository = photoRepository;
        _logger = logger;
    }

    public async Task<List<FavouritePlaceDto>> GetFavouritePlacesAsync(int userId)
    {
        var places = await _repository.GetFavouritePlacesByUserIdAsync(userId);
        var photos = await _photoRepository.GetByPlaceIdsAsync(
            places.Select(p => p.PlaceId).Distinct().ToList());
        return places.Select(p => ToDto(p, photos)).ToList();
    }

    public async Task<FavouritePlaceDto> AddFavouritePlaceAsync(int userId, AddFavouritePlaceRequestDto request)
    {
        var existing = await _repository.GetFavouritePlaceByUserAndPlaceIdAsync(userId, request.PlaceId);
        if (existing is not null)
        {
            _logger.LogWarning("Add favourite place failed for user {UserId}: place {PlaceId} is already favourited.", userId, request.PlaceId);
            throw new ConflictException("This place is already in your favourites.");
        }

        var place = await _repository.GetPlaceByIdAsync(request.PlaceId);
        var isNewPlace = place is null;
        place ??= new DomainPlace { PlaceId = request.PlaceId, CreatedAt = DateTime.UtcNow };

        place.Name = request.Name;
        place.PrimaryType = request.PrimaryType;
        place.Address = request.Address ?? place.Address;
        place.Latitude = request.Latitude;
        place.Longitude = request.Longitude;
        place.UpdatedAt = DateTime.UtcNow;

        var cached = await _repository.GetLatestHiddenPlaceCacheByPlaceIdAsync(request.PlaceId);
        if (cached is not null)
        {
            place.Rating = cached.Rating;
            place.UserRatingCount = cached.UserRatingCount;
            place.PriceLevel = cached.PriceLevel;
            place.BusinessStatus = cached.BusinessStatus;
            place.GoogleMapsUri = cached.GoogleMapsUri;
            place.NationalPhoneNumber = cached.NationalPhoneNumber;
            place.WebsiteUri = cached.WebsiteUri;
            place.PhotosJson = cached.PhotosJson;
            place.RegularOpeningHoursJson = cached.RegularOpeningHoursJson;
            place.ShortFormattedAddress = cached.ShortFormattedAddress;
            place.PrimaryTypeDisplayName = cached.PrimaryTypeDisplayName;
            place.AccessibilityOptionsJson = cached.AccessibilityOptionsJson;
            place.AddressComponentsJson = cached.AddressComponentsJson;
            place.GoogleMapsLinksJson = cached.GoogleMapsLinksJson;
            place.ViewportJson = cached.ViewportJson;
            place.OpeningDate = cached.OpeningDate;
        }
        else
        {
            _logger.LogWarning("No hidden_place_cache entry found for place {PlaceId} when favouriting — rich details will be empty.", request.PlaceId);
        }

        if (isNewPlace)
        {
            await _repository.AddPlaceAsync(place);
        }
        else
        {
            await _repository.UpdatePlaceAsync(place);
        }

        var favouritePlace = new DomainFavouritePlace
        {
            UserId = userId,
            PlaceId = request.PlaceId,
            CreatedAt = DateTime.UtcNow
        };

        await _repository.AddFavouritePlaceAsync(favouritePlace);

        favouritePlace.Place = place;

        var photos = await _photoRepository.GetByPlaceIdsAsync(new[] { request.PlaceId });
        return ToDto(favouritePlace, photos);
    }

    public async Task RemoveFavouritePlacesAsync(int userId, RemoveFavouritePlacesRequestDto request)
    {
        await _repository.RemoveFavouritePlacesAsync(userId, request.FavouritePlaceIds);
    }

    private static FavouritePlaceDto ToDto(DomainFavouritePlace favourite, IReadOnlyDictionary<string, PlacePhoto> photos)
    {
        photos.TryGetValue(favourite.PlaceId, out var photo);

        return new FavouritePlaceDto
        {
            FavouritePlaceId = favourite.FavouritePlaceId,
            PlaceId = favourite.PlaceId,
            Name = favourite.Place?.Name ?? string.Empty,
            PrimaryType = favourite.Place?.PrimaryType ?? string.Empty,
            Address = favourite.Place?.Address,
            Latitude = favourite.Place?.Latitude ?? 0,
            Longitude = favourite.Place?.Longitude ?? 0,
            LastVisitAt = favourite.LastVisitAt,
            CreatedAt = favourite.CreatedAt,
            PhotoUrl = photo?.PhotoUrl,
            PhotoAttribution = photo?.Attribution
        };
    }
}