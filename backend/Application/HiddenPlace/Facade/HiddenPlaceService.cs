using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;
using ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.DTOs.HiddenPlace;
using HiddenPlaceEntity = ExploreMy.Api.Domain.Entities.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.Facade;

/// <summary>
/// Orchestrates the hidden-place-discovery flow:
///
///   1) Split the request into (type x geographic cell) buckets - SearchGridPlanner.
///   2) Check the DB cache for buckets that were already fetched recently - one batched read.
///   3) For buckets that missed the cache, fetch them from Google Places API concurrently
///      (bounded, so we don't fire dozens of simultaneous HTTP calls).
///   4) Write the freshly-fetched buckets back to the cache - one batched write.
///   5) Merge cached + freshly-fetched candidates, dedupe by PlaceId, and hand them to
///      DiscoverHiddenPlaceService for the hidden-gem quality gate + scoring.
///
/// The controller only talks to this class - it doesn't need to know Google, the cache, or the
/// scoring algorithm exist.
/// </summary>
public class HiddenPlaceService : IHiddenPlaceService
{
    // Sensible default mix when the caller doesn't specify types - covers both "attractions" and "food".
    private static readonly List<string> DefaultTypes = new()
    {
        "tourist_attraction", "restaurant", "cafe", "museum", "scenic_spot"
    };

    // How long a cached bucket stays usable before it's re-fetched from Google. Hidden-gem signals
    // (rating, review count) drift slowly - a place that's obscure today is still obscure next week -
    // so a long TTL is what actually saves API calls/cost across repeat and nearby searches. The
    // trade-off at 30 days: a bucket fetched a month ago serves month-old ratings and review counts,
    // and newly-opened places in that cell stay invisible until it expires. Since HiddenScore is
    // computed from review counts, badly stale data can rank a place that has since gone viral as
    // still "hidden". Shorten this if results start feeling out of date.
    private static readonly TimeSpan CacheTtl = TimeSpan.FromDays(30);

    // Caps how many Google Places calls run at once for a single request, so a big/dense search
    // doesn't fire dozens of simultaneous HTTP calls at once.
    private const int MaxConcurrentFetches = 8;

    private readonly IPlacesApiClient _placesApiClient;
    private readonly IHiddenPlaceRepository _hiddenPlaceRepository;
    private readonly IDiscoverHiddenPlaceService _discoverHiddenPlaceService;
    private readonly ILogger<HiddenPlaceService> _logger;

    public HiddenPlaceService(
        IPlacesApiClient placesApiClient,
        IHiddenPlaceRepository hiddenPlaceRepository,
        IDiscoverHiddenPlaceService discoverHiddenPlaceService,
        ILogger<HiddenPlaceService> logger)
    {
        _placesApiClient = placesApiClient;
        _hiddenPlaceRepository = hiddenPlaceRepository;
        _discoverHiddenPlaceService = discoverHiddenPlaceService;
        _logger = logger;
    }

    public async Task<List<HiddenPlaceResponseItemDto>> DiscoverHiddenPlacesAsync(
        DiscoverHiddenPlaceRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var types = request.Types is { Count: > 0 } ? request.Types! : DefaultTypes;

        var buckets = SearchGridPlanner.BuildBuckets(
            request.Latitude, request.Longitude, request.RadiusMeters, types);

        var now = DateTime.UtcNow;
        var freshCache = await _hiddenPlaceRepository.GetFreshBucketsAsync(
            buckets.Select(b => b.BucketKey).ToList(), now - CacheTtl);

        var bucketsNeedingFetch = buckets.Where(b => !freshCache.ContainsKey(b.BucketKey)).ToList();

        _logger.LogInformation(
            "Hidden-place search near ({Lat}, {Lng}): {TotalBuckets} buckets, {CacheHits} from cache, {CacheMisses} to fetch from Google.",
            request.Latitude, request.Longitude, buckets.Count, freshCache.Count, bucketsNeedingFetch.Count);

        var fetched = await FetchBucketsAsync(bucketsNeedingFetch, request.MaxResultCount, cancellationToken);

        if (fetched.Count > 0)
        {
            await _hiddenPlaceRepository.ReplaceBucketsAsync(fetched, now);
        }

        // Merge cache hits + freshly-fetched buckets, then dedupe by PlaceId - the same real place can
        // legitimately show up in more than one bucket (neighboring cells overlap a little on purpose,
        // and Google can return the same place under more than one requested type).
        //
        // Cell membership (SearchGridPlanner.BuildBuckets) is deliberately loose - a cell is included if
        // it merely overlaps the requested radius, not if every place inside it does. So a cell can be a
        // couple of km past the user's radius and still get scanned, and Google can return places from
        // anywhere in that cell's own circle. Without this filter, a place at the far edge of an included
        // cell can end up well outside the radius the user actually asked for (e.g. a 5km search pulling
        // in a place ~9-10km away). This is the exact-distance check that enforces the promised radius.
        var candidates = freshCache.Values.SelectMany(v => v)
            .Concat(fetched.Values.SelectMany(v => v))
            .GroupBy(e => e.PlaceId)
            .Select(g => ToPlaceCandidate(g.First()))
            .Where(c => SearchGridPlanner.DistanceMeters(
                request.Latitude, request.Longitude, c.Latitude, c.Longitude) <= request.RadiusMeters)
            .ToList();

        var results = _discoverHiddenPlaceService.Discover(candidates);

        _logger.LogInformation(
            "{SurvivorCount}/{CandidateCount} candidates passed the quality gate near ({Lat}, {Lng}).",
            results.Count, candidates.Count, request.Latitude, request.Longitude);

        return results.Select(MapToResponseDto).ToList();
    }

    /// <summary>
    /// Fetches every bucket that missed the cache, bounded to MaxConcurrentFetches at a time. A
    /// bucket whose Google Places call fails is logged and skipped rather than failing the whole
    /// request - a partial result set beats no result set. Only touches HttpClient here, never the
    /// DbContext, so this is safe to run concurrently (DbContext itself is NOT thread-safe, which is
    /// why the cache write in DiscoverHiddenPlacesAsync happens afterwards, sequentially).
    /// </summary>
    private async Task<Dictionary<string, List<HiddenPlaceEntity>>> FetchBucketsAsync(
        List<SearchBucket> bucketsToFetch, int maxResultCount, CancellationToken cancellationToken)
    {
        var result = new Dictionary<string, List<HiddenPlaceEntity>>();
        if (bucketsToFetch.Count == 0)
        {
            return result;
        }

        using var throttle = new SemaphoreSlim(MaxConcurrentFetches);

        var tasks = bucketsToFetch.Select(async bucket =>
        {
            await throttle.WaitAsync(cancellationToken);
            try
            {
                var candidates = await _placesApiClient.SearchNearbyAsync(
                    bucket.CenterLatitude,
                    bucket.CenterLongitude,
                    bucket.RadiusMeters,
                    new[] { bucket.PlaceType },
                    maxResultCount,
                    cancellationToken);

                return (bucket.BucketKey, Entities: candidates.Select(ToEntity).ToList());
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Places API fetch failed for bucket {BucketKey} - skipping it.", bucket.BucketKey);
                return (bucket.BucketKey, Entities: new List<HiddenPlaceEntity>());
            }
            finally
            {
                throttle.Release();
            }
        });

        var completed = await Task.WhenAll(tasks);
        foreach (var (bucketKey, entities) in completed)
        {
            result[bucketKey] = entities;
        }
        return result;
    }

    // Instance method (not static) because it needs _discoverHiddenPlaceService to tag each row with
    // whether it passes the quality gate - see HiddenPlace.PassedQualityGate's doc comment for why this
    // is the absolute/stage-1 check only, not the final relative HiddenScore.
    private HiddenPlaceEntity ToEntity(PlaceCandidate place) => new()
    {
        PlaceId = place.PlaceId,
        Name = place.Name,
        PrimaryType = place.PrimaryType,
        Latitude = place.Latitude,
        Longitude = place.Longitude,
        Rating = place.Rating,
        UserRatingCount = place.UserRatingCount,
        PriceLevel = place.PriceLevel,
        BusinessStatus = place.BusinessStatus,
        PassedQualityGate = _discoverHiddenPlaceService.PassesQualityGate(place)
    };

    private static PlaceCandidate ToPlaceCandidate(HiddenPlaceEntity entity) => new()
    {
        PlaceId = entity.PlaceId,
        Name = entity.Name,
        PrimaryType = entity.PrimaryType,
        Latitude = entity.Latitude,
        Longitude = entity.Longitude,
        Rating = entity.Rating,
        UserRatingCount = entity.UserRatingCount,
        PriceLevel = entity.PriceLevel,
        BusinessStatus = entity.BusinessStatus
    };

    private static HiddenPlaceResponseItemDto MapToResponseDto(HiddenPlaceResult result) => new()
    {
        PlaceId = result.Place.PlaceId,
        Name = result.Place.Name,
        PrimaryType = result.Place.PrimaryType,
        Latitude = result.Place.Latitude,
        Longitude = result.Place.Longitude,
        Rating = result.Place.Rating,
        UserRatingCount = result.Place.UserRatingCount,
        PriceLevel = result.Place.PriceLevel,
        HiddenScore = result.HiddenScore
    };
}
