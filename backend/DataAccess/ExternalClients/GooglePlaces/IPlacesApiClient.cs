using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

namespace ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;

public interface IPlacesApiClient
{
    /// <summary>
    /// Searches Google Places API (New) "searchNearby" for places of the given types within
    /// <paramref name="radiusMeters"/> of the given center point, and maps the results into
    /// <see cref="PlaceCandidate"/> ready for DiscoverHiddenPlaceService to score.
    /// </summary>
    /// <param name="latitude">Search center latitude.</param>
    /// <param name="longitude">Search center longitude.</param>
    /// <param name="radiusMeters">Search radius in meters. Google caps this at 50000.</param>
    /// <param name="includedTypes">
    /// Places API type strings, e.g. "restaurant", "cafe", "tourist_attraction".
    /// See https://developers.google.com/maps/documentation/places/web-service/place-types
    /// </param>
    /// <param name="maxResultCount">Max results to return (1-20 per Google's limit).</param>
    Task<IReadOnlyList<PlaceCandidate>> SearchNearbyAsync(
        double latitude,
        double longitude,
        int radiusMeters,
        IReadOnlyList<string> includedTypes,
        int maxResultCount = 20,
        CancellationToken cancellationToken = default);
}
