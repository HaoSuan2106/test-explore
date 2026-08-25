using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.Facade;

public interface IHiddenPlaceService
{
    /// <summary>Fetches nearby places from Google Places API and returns them ranked by hidden-gem score.</summary>
    Task<List<HiddenPlaceResponseItemDto>> DiscoverHiddenPlacesAsync(
        DiscoverHiddenPlaceRequestDto request,
        CancellationToken cancellationToken = default);
}
