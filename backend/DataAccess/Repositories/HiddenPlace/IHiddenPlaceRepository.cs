using HiddenPlaceEntity = ExploreMy.Api.Domain.Entities.HiddenPlace;

namespace ExploreMy.Api.DataAccess.Repositories.HiddenPlace;

public interface IHiddenPlaceRepository
{
    /// <summary>
    /// Reads all cache buckets in <paramref name="cacheGridKeys"/> that are still fresh (their
    /// FetchedAtUtc is at or after <paramref name="minFetchedAtUtc"/>), in a single query. A bucket
    /// that's missing entirely or stale is simply absent from the returned dictionary - the caller
    /// treats an absent key as a cache miss and knows it needs to fetch that bucket from Google.
    /// </summary>
    Task<Dictionary<string, List<HiddenPlaceEntity>>> GetFreshBucketsAsync(
        IReadOnlyCollection<string> cacheGridKeys, DateTime minFetchedAtUtc);

    /// <summary>
    /// Replaces the cached rows for every bucket key in <paramref name="placesByBucketKey"/> with the
    /// given freshly-fetched places (old rows for those buckets are deleted, new ones inserted),
    /// stamping <paramref name="fetchedAtUtc"/> on all of them, in one batched write.
    /// </summary>
    Task ReplaceBucketsAsync(
        IReadOnlyDictionary<string, List<HiddenPlaceEntity>> placesByBucketKey, DateTime fetchedAtUtc);
}
