using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.PlacePhotos;

/// <summary>What the app needs in order to show a place's picture and credit whoever took it.</summary>
public sealed record PlacePhotoInfo(string Url, string? Attribution);

public interface IPlacePhotoService
{
    /// <summary>
    /// Returns a photo for each of <paramref name="places"/> that has one, copying any that have not
    /// been copied yet from Google into our Supabase bucket first.
    ///
    /// Places with no photo available are absent from the result rather than mapped to null - the
    /// caller shows its own placeholder for those.
    ///
    /// Never throws. Photos are a nice-to-have on top of a search result; a Google outage, a Supabase
    /// outage or a single corrupt image must not turn a working search into an error page. Anything
    /// that fails is logged and simply missing from the returned map, and will be retried on the next
    /// search that includes that place.
    /// </summary>
    Task<IReadOnlyDictionary<string, PlacePhotoInfo>> EnsurePhotosAsync(
        IReadOnlyCollection<PlaceCandidate> places,
        CancellationToken cancellationToken = default);
}
