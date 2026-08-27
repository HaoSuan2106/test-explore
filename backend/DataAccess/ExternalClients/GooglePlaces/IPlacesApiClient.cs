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

    /// <summary>
    /// Resolves a Google photo RESOURCE NAME (the "name" field inside a place's photos array, e.g.
    /// "places/ChIJ.../photos/AeJbb3E...") into a URI the image bytes can actually be downloaded from.
    ///
    /// This is the call Place Photos bills for - $7 per 1,000 images, 1,000 free a month - so it
    /// should only ever run for a place whose photo has not already been copied into our own storage.
    /// The returned URI is short-lived and signed for one host, so it is only useful for downloading
    /// immediately; it must not be handed to the app or written to the database.
    /// </summary>
    /// <param name="photoReference">The photo resource name from the place's photos array.</param>
    /// <param name="maxWidthPx">Requested width. Does not affect price, only bytes and load time.</param>
    /// <returns>The download URI, or null if Google had no image for that reference.</returns>
    Task<string?> GetPhotoUriAsync(
        string photoReference,
        int maxWidthPx,
        CancellationToken cancellationToken = default);
}
