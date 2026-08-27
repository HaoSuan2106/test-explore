using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.DataAccess.Repositories.PlacePhotos;

public interface IPlacePhotoRepository
{
    /// <summary>
    /// Looks up the already-copied photos for the given place ids in one query, keyed by place id.
    /// A place with no row yet is simply absent - the caller treats that as "not bought from Google
    /// yet" and fetches it.
    /// </summary>
    Task<Dictionary<string, PlacePhoto>> GetByPlaceIdsAsync(IReadOnlyCollection<string> placeIds);

    /// <summary>
    /// Inserts newly-copied photos. Implementations must treat a duplicate place id as harmless
    /// rather than an error: two searches running at once can copy the same place's photo
    /// simultaneously, and losing that race is not a reason to fail a user's search.
    /// </summary>
    Task AddRangeAsync(IReadOnlyCollection<PlacePhoto> photos);
}
