using HiddenPlaceEntity = ExploreMy.Api.Domain.Entities.HiddenPlace;

using ExploreMy.Api.Domain.Entities;

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

    /// <summary>
    /// Reads the distinct, non-empty <c>primary_type</c> values currently present in the
    /// <c>hidden_place_cache</c> table, sorted alphabetically. Used ONLY as a read-only data source
    /// for the "Recommend New Place" Primary Type selector — the cache itself is never written here.
    /// </summary>
    Task<List<string>> GetDistinctPrimaryTypesAsync();

    /// <summary>
    /// Looks up a Google-sourced place by its Google Place ID from the
    /// <c>hidden_place_cache</c> table. Returns <c>null</c> when the place is not
    /// in the cache (e.g. the cache bucket was evicted since the place was displayed).
    /// Used by the report flow to resolve a Google place ID sent by the UI's
    /// Community Verification / Report Place screen (which is reachable from both
    /// community recommendations and Google-sourced hidden places).
    /// </summary>
    Task<HiddenPlaceEntity?> GetGooglePlaceByIdAsync(string placeId);
    // ——— Recommended Places (normalized: canonical place + submission) ———
    Task<List<PlaceSubmission>> GetBySubmitterAsync(int userId);
    Task<List<PlaceSubmission>> GetPublishedPlacesAsync();
    Task<PlaceSubmission?> GetByIdAsync(string submissionId);
    Task<bool> ExistsByNameAsync(string name);
    Task<bool> ExistsNearbyAsync(decimal latitude, decimal longitude, double radiusMeters);

    /// <summary>
    /// Creates the canonical place row and the submission row in ONE transaction
    /// (place first, then submission referencing it).
    /// </summary>
    Task CreateSubmissionAsync(RecommendPlace place, PlaceSubmission submission);
    Task UpdateSubmissionAsync(PlaceSubmission submission);

    /// <summary>
    /// Updates the canonical place row (<c>recommended_places</c>) AND the
    /// submission timestamp (<c>place_submissions.updated_at</c>) in ONE
    /// transaction — the UPDATE half of the recommendation lifecycle.
    /// </summary>
    Task UpdateRecommendationAsync(RecommendPlace place, PlaceSubmission submission);

    // ——— Verifications (voting) ———
    Task<PlaceSubmissionVerification?> GetActiveVerificationAsync(string submissionId, int userId);
    Task<PlaceSubmissionVerification?> GetAnyVerificationAsync(string submissionId, int userId);
    Task CreateVerificationAsync(PlaceSubmissionVerification verification);
    Task UpdateVerificationAsync(PlaceSubmissionVerification verification);
    Task DeleteVerificationAsync(PlaceSubmissionVerification verification);
    Task<int> GetActiveVerificationCountAsync(string submissionId);
}
