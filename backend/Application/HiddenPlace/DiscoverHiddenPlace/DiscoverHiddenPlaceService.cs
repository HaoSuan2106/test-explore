//using ExploreMy.Api.Application.HiddenPlace.Facade;
//using ExploreMy.Api.Application.HiddenPlace.PlacePhotos;
//using ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;
//using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
//using ExploreMy.Api.Domain.Entities;
//using ExploreMy.Api.DTOs.HiddenPlace;
//using HiddenPlaceEntity = ExploreMy.Api.Domain.Entities.HiddenPlace;

//namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

///// <summary>
///// Hidden-place discovery: the "冷门度" (hidden-gem) algorithm PLUS the orchestration that feeds it.
/////
///// The algorithm runs in three stages:
/////   1) Quality gate  - drop places that are closed, unrated/under-reviewed, or a known chain brand.
/////                       These aren't "hidden gems" - they're untrustworthy data points, or inherently
/////                       not hidden regardless of how few reviews they have locally.
/////   2) The ceiling   - drop places that are among the best known of their own type in this search. This
/////                       is what enforces "lots of reviews means not hidden"; the cutoff is a percentile
/////                       rather than a fixed count, because the count that means "famous" differs by type
/////                       and by area. See BuildReviewCeilings.
/////   3) Scoring       - rank whatever is left by how few people know about them (review count, compared
/////                       against similar nearby places rather than a global pool) balanced against
/////                       how good they actually are (rating). Optionally trimmed at the bottom by
/////                       MinHiddenScore, which is off by default - see that setting for why.
/////
///// The orchestration (DiscoverHiddenPlacesAsync) owns the full pipeline the facade delegates to:
///// cache read, Google Places fetch, suppression filtering, community merge, photo merge, and response
///// mapping. The algorithm itself stays pure computation - it takes already-fetched candidates in and
///// returns a ranked list out.
///// </summary>
//public class DiscoverHiddenPlaceService : IDiscoverHiddenPlaceService
//{
//    // Sensible default mix when the caller doesn't specify types - covers both "attractions" and "food".
//    private static readonly List<string> DefaultTypes = new()
//    {
//        "tourist_attraction", "restaurant", "cafe", "museum", "scenic_spot"
//    };

//    // How long a cached bucket stays usable before it's re-fetched from Google. Hidden-gem signals
//    // (rating, review count) drift slowly - a place that's obscure today is still obscure next week -
//    // so a long TTL is what actually saves API calls/cost across repeat and nearby searches. The
//    // trade-off at 30 days: a bucket fetched a month ago serves month-old ratings and review counts,
//    // and newly-opened places in that cell stay invisible until it expires. Since HiddenScore is
//    // computed from review counts, badly stale data can rank a place that has since gone viral as
//    // still "hidden". Shorten this if results start feeling out of date.
//    private static readonly TimeSpan CacheTtl = TimeSpan.FromDays(30);

//    // Caps how many Google Places calls run at once for a single request, so a big/dense search
//    // doesn't fire dozens of simultaneous HTTP calls at once.
//    private const int MaxConcurrentFetches = 8;

//    private readonly IPlacesApiClient _placesApiClient;
//    private readonly IHiddenPlaceRepository _repository;
//    private readonly IHiddenPlaceSuppressionRepository _suppressionRepository;
//    private readonly IPlacePhotoService _placePhotoService;
//    private readonly ILogger<DiscoverHiddenPlaceService> _logger;

//    public DiscoverHiddenPlaceService(
//        IPlacesApiClient placesApiClient,
//        IHiddenPlaceRepository repository,
//        IHiddenPlaceSuppressionRepository suppressionRepository,
//        IPlacePhotoService placePhotoService,
//        ILogger<DiscoverHiddenPlaceService> logger)
//    {
//        _placesApiClient = placesApiClient;
//        _repository = repository;
//        _suppressionRepository = suppressionRepository;
//        _placePhotoService = placePhotoService;
//        _logger = logger;
//    }

//    // ============================================================
//    //  Discovery pipeline (orchestration)
//    // ============================================================

//    public async Task<List<HiddenPlaceResponseItemDto>> DiscoverHiddenPlacesAsync(
//        DiscoverHiddenPlaceRequestDto request,
//        CancellationToken cancellationToken = default)
//    {
//        var types = request.Types is { Count: > 0 } ? request.Types! : DefaultTypes;

//        var buckets = SearchGridPlanner.BuildBuckets(
//            request.Latitude, request.Longitude, request.RadiusMeters, types);

//        var now = DateTime.UtcNow;
//        var freshCache = await _repository.GetFreshBucketsAsync(
//            buckets.Select(b => b.BucketKey).ToList(), now - CacheTtl);

//        var bucketsNeedingFetch = buckets.Where(b => !freshCache.ContainsKey(b.BucketKey)).ToList();

//        _logger.LogInformation(
//            "Hidden-place search near ({Lat}, {Lng}): {TotalBuckets} buckets, {CacheHits} from cache, {CacheMisses} to fetch from Google.",
//            request.Latitude, request.Longitude, buckets.Count, freshCache.Count, bucketsNeedingFetch.Count);

//        var fetched = await FetchBucketsAsync(bucketsNeedingFetch, request.MaxResultCount, cancellationToken);

//        if (fetched.Count > 0)
//        {
//            await _repository.ReplaceBucketsAsync(fetched, now);
//        }

//        // Merge cache hits + freshly-fetched buckets, then dedupe by PlaceId - the same real place can
//        // legitimately show up in more than one bucket. Neighboring cells' search circles overlap
//        // substantially by design (each is its square cell's circumscribed circle, so adjacent circles
//        // must intersect for the corners between them to be covered at all - see
//        // SearchGridPlanner.CellSearchRadiusMeters), and Google can also return the same place under
//        // more than one requested type.
//        //
//        // Cell membership (SearchGridPlanner.BuildBuckets) is deliberately loose - a cell is included if
//        // it merely overlaps the requested radius, not if every place inside it does. So a cell can be a
//        // couple of km past the user's radius and still get scanned, and Google can return places from
//        // anywhere in that cell's own circle. Without this filter, a place at the far edge of an included
//        // cell can end up well outside the radius the user actually asked for (e.g. a 5km search pulling
//        // in a place ~9-10km away). This is the exact-distance check that enforces the promised radius.
//        //
//        // Places the community has reported out of existence. Applied HERE, on the way out, rather
//        // than by deleting cache rows: hidden_place_cache is refilled from Google every 30 days, so a
//        // deleted row simply comes back and the reports are silently undone. Excluding at read time
//        // is the only thing a refresh cannot overwrite.
//        var suppressedPlaceIds = await _suppressionRepository.GetSuppressedPlaceIdsAsync();

//        var candidates = freshCache.Values.SelectMany(v => v)
//            .Concat(fetched.Values.SelectMany(v => v))
//            .GroupBy(e => e.PlaceId)
//            .Select(g => ToPlaceCandidate(g.First()))
//            .Where(c => !suppressedPlaceIds.Contains(c.PlaceId))
//            .Where(c => SearchGridPlanner.DistanceMeters(
//                request.Latitude, request.Longitude, c.Latitude, c.Longitude) <= request.RadiusMeters)
//            .ToList();

//        var results = Discover(candidates);

//        _logger.LogInformation(
//            "{SurvivorCount}/{CandidateCount} candidates passed the quality gate near ({Lat}, {Lng}).",
//            results.Count, candidates.Count, request.Latitude, request.Longitude);

//        // Photos last, and only for the places that actually survived scoring. Doing it earlier would
//        // mean paying Google for images of places the quality gate is about to throw away. Never
//        // throws - a search without pictures is still a search.
//        var photos = await _placePhotoService.EnsurePhotosAsync(
//            results.Select(r => r.Place).ToList(), cancellationToken);

//        var response = results.Select(result => MapToResponseDto(result, photos)).ToList();

//        // Community picks are appended, never interleaved. Their ordering key would have to be
//        // HiddenScore, and they do not have one - the score is computed from Google review counts,
//        // which a user submission has none of. Giving them a made-up score to sort by would put them
//        // in a position that means nothing; putting them after the ranked list says plainly "these
//        // are extra, and they are ordered by newest".
//        response.AddRange(await GetVerifiedCommunityPlacesAsync(request));

//        return response;
//    }

//    // ============================================================
//    //  Quality gate + scoring (algorithm)
//    // ============================================================

//    public IReadOnlyList<HiddenPlaceResult> Discover(
//        IEnumerable<PlaceCandidate> candidates,
//        DiscoverHiddenPlaceOptions? options = null)
//    {
//        options ??= new DiscoverHiddenPlaceOptions();

//        // Two pools, and keeping them apart is load-bearing.
//        //
//        // referencePool is what scoring COMPARES AGAINST: every trustworthy place, deliberately including
//        // the well-known ones the ceiling will stop us returning. It answers "how well-known do places of
//        // this type get around here?" - a fact about the area, which must not change just because the app
//        // has decided not to show the well-known ones. The famous museum down the road is exactly the
//        // yardstick that makes a quiet one look obscure.
//        //
//        // Scoring off the returned set instead is self-referential: excluding popular places lowers each
//        // group's maximum, which is the divisor in NormalizeReviewCount, which inflates every remaining
//        // place's popularityNorm and so deflates every HiddenScore. Measured on a real KL search, applying
//        // a 500 ceiling that way pushed the top score from 0.751 down to 0.626 and cut the surviving
//        // results from 54 to 13 - the two settings multiplied instead of acting independently.
//        var referencePool = candidates.Where(place => PassesBaseQualityChecks(place, options)).ToList();
//        if (referencePool.Count == 0)
//        {
//            return Array.Empty<HiddenPlaceResult>();
//        }

//        // survivors is what actually gets scored and returned: everything trustworthy that isn't among the
//        // best-known of its own type. See BuildReviewCeilings for why the cutoff is a percentile per type
//        // rather than one review count for everything.
//        var reviewCeilings = BuildReviewCeilings(referencePool, options);
//        var survivors = referencePool
//            .Where(place => place.UserRatingCount <= reviewCeilings.For(place.PrimaryType))
//            .ToList();
//        if (survivors.Count == 0)
//        {
//            return Array.Empty<HiddenPlaceResult>();
//        }

//        // Fallback comparison pool for local groups that are too small to judge fairly on their own.
//        var globalMaxReviewCount = referencePool.Max(p => p.UserRatingCount);

//        var localGroups = referencePool
//            .GroupBy(p => BuildGroupKey(p, options.LocalGroupGridSizeDegrees))
//            .ToDictionary(g => g.Key, g => g.ToList());

//        var results = new List<HiddenPlaceResult>(survivors.Count);

//        foreach (var place in survivors)
//        {
//            var group = localGroups[BuildGroupKey(place, options.LocalGroupGridSizeDegrees)];

//            var comparisonMax = group.Count >= options.MinGroupSizeForLocalComparison
//                ? group.Max(p => p.UserRatingCount)
//                : globalMaxReviewCount;

//            var popularityNorm = NormalizeReviewCount(place.UserRatingCount, comparisonMax);
//            var ratingNorm = NormalizeRating(place.Rating, options.MinRating);

//            var hiddenScore =
//                options.PopularityWeight * (1 - popularityNorm) +
//                options.QualityWeight * ratingNorm;

//            results.Add(new HiddenPlaceResult
//            {
//                Place = place,
//                HiddenScore = Math.Clamp(hiddenScore, 0, 1),
//                PopularityNorm = popularityNorm,
//                RatingNorm = ratingNorm
//            });
//        }

//        // Optional bottom trim. The ceiling above already removed the well-known places, so this is off
//        // (0) by default - see DiscoverHiddenPlaceOptions.MinHiddenScore for why it is a poor primary
//        // filter and what it is still useful for.
//        //
//        // The two ThenBy keys are what make the ranking reproducible, not just sorted. LINQ's OrderBy is a
//        // stable sort, so ties keep their INPUT order - and the input is whatever order MySQL handed the
//        // cached rows back in, which is unspecified without an ORDER BY. Ties are not a corner case here:
//        // HiddenScore blends two signals, so genuinely different places collide on the same value (a
//        // 25-review museum and a 1663-review temple both scored 0.411 on a real KL search). Without these,
//        // running the same search twice can hand back the same places in a different order.
//        //
//        // UserRatingCount first because it is the tie-break a user would expect: same score, fewer people
//        // know about it, so it is the more "hidden" of the two. PlaceId last purely for determinism - it
//        // carries no meaning, it just guarantees a total order so the output is a function of the input.
//        return results
//            .Where(r => r.HiddenScore >= options.MinHiddenScore)
//            .OrderByDescending(r => r.HiddenScore)
//            .ThenBy(r => r.Place.UserRatingCount)
//            .ThenBy(r => r.Place.PlaceId, StringComparer.Ordinal)
//            .ToList();
//    }

//    /// <summary>
//    /// Everything about a candidate that can be judged from its own fields alone - business status, rating,
//    /// the review-count floor, the absolute review-count ceiling, and the name. Exposed publicly (rather
//    /// than kept as a private filter inside Discover) so callers that persist raw Places API data - see
//    /// HiddenPlaceService writing to the hidden_place_cache table - can record whether a place would pass
//    /// without running the full Discover pipeline.
//    ///
//    /// This is deliberately NOT the whole of what Discover applies. The percentile ceiling that does most
//    /// of the "too well-known" work is derived from the other places in the same search (see
//    /// BuildReviewCeilings), so it cannot be evaluated one place at a time and is not included here. A row
//    /// stamped as passing this gate is therefore saying "trustworthy, and not famous in absolute terms" -
//    /// not "this would be returned to a user".
//    /// </summary>
//    public bool PassesQualityGate(PlaceCandidate place, DiscoverHiddenPlaceOptions? options = null)
//    {
//        options ??= new DiscoverHiddenPlaceOptions();

//        return PassesBaseQualityChecks(place, options)
//               && place.UserRatingCount <= options.MaxUserRatingCount;
//    }

//    /// <summary>
//    /// Everything the quality gate checks EXCEPT the MaxUserRatingCount ceiling: is this a real, open,
//    /// independently-run place with enough reviews to be worth trusting?
//    ///
//    /// Split out because the two questions are asked at different moments. "Is this data trustworthy?"
//    /// decides who belongs in the comparison pool HiddenScore is measured against; "is this too well-known
//    /// to show?" decides who gets returned. A famous museum belongs in the first group and not the second.
//    /// See the comment on referencePool in Discover for what went wrong when both were one filter.
//    /// </summary>
//    private static bool PassesBaseQualityChecks(PlaceCandidate place, DiscoverHiddenPlaceOptions options)
//    {
//        if (!options.AllowedBusinessStatuses.Contains(place.BusinessStatus))
//            return false;

//        if (place.Rating is null || place.Rating < options.MinRating)
//            return false;

//        if (place.UserRatingCount < options.MinUserRatingCount)
//            return false;

//        if (options.ChainBrandKeywords.Any(keyword =>
//                place.Name.Contains(keyword, StringComparison.OrdinalIgnoreCase)))
//            return false;

//        return true;
//    }

//    /// <summary>The review-count ceiling that applies to each primary type in one search.</summary>
//    private sealed class ReviewCeilings
//    {
//        private readonly Dictionary<string, double> _byPrimaryType;
//        private readonly double _fallback;

//        public ReviewCeilings(Dictionary<string, double> byPrimaryType, double fallback)
//        {
//            _byPrimaryType = byPrimaryType;
//            _fallback = fallback;
//        }

//        public double For(string primaryType) =>
//            _byPrimaryType.TryGetValue(primaryType, out var ceiling) ? ceiling : _fallback;
//    }

//    /// <summary>
//    /// Works out, per primary type, how many reviews is "too many to still be hidden" for THIS search.
//    ///
//    /// The cutoff is a percentile of what the search actually found rather than a constant, because the
//    /// number that means "well-known" is not portable. It differs by type - in sampled KL data the 60th
//    /// percentile was 129 reviews for coffee_shop but 1066 for museum, because museums simply collect more
//    /// reviews than cafes - and it differs by area, since a count that marks a place as famous downtown can
//    /// exceed everything in a small town. Deriving it from the current result set handles both without any
//    /// per-city or per-type table to maintain.
//    ///
//    /// Types with fewer than MinGroupSizeForPercentileCeiling members fall back to the percentile over the
//    /// whole pool: a percentile across two or three places is noise, and if those few happen to be famous it
//    /// would compute a ceiling high enough to admit all of them. Every ceiling is then clamped by the
//    /// absolute MaxUserRatingCount, which covers the case where a whole search is landmarks and even the
//    /// least famous 60% of them are not hidden by any reasonable reading.
//    /// </summary>
//    private static ReviewCeilings BuildReviewCeilings(
//        IReadOnlyList<PlaceCandidate> referencePool, DiscoverHiddenPlaceOptions options)
//    {
//        double absoluteCeiling = options.MaxUserRatingCount;

//        double CeilingFor(IEnumerable<PlaceCandidate> places) => Math.Min(
//            Percentile(places.Select(p => p.UserRatingCount).OrderBy(n => n).ToList(),
//                       options.MaxUserRatingPercentile),
//            absoluteCeiling);

//        var byPrimaryType = referencePool
//            .GroupBy(p => p.PrimaryType)
//            .Where(g => g.Count() >= options.MinGroupSizeForPercentileCeiling)
//            .ToDictionary(g => g.Key, g => CeilingFor(g));

//        return new ReviewCeilings(byPrimaryType, CeilingFor(referencePool));
//    }

//    /// <summary>
//    /// Linear-interpolated percentile over an ALREADY SORTED ascending list. Interpolated rather than
//    /// nearest-rank so that small groups - which is most of them, since a search rarely returns many places
//    /// of any one type - don't make the ceiling jump between two members' review counts.
//    /// </summary>
//    private static double Percentile(IReadOnlyList<int> sortedValues, double percentile)
//    {
//        if (sortedValues.Count == 0) return 0;
//        if (sortedValues.Count == 1) return sortedValues[0];

//        var rank = (sortedValues.Count - 1) * Math.Clamp(percentile, 0, 1);
//        var lower = (int)Math.Floor(rank);
//        var upper = (int)Math.Ceiling(rank);
//        if (lower == upper) return sortedValues[lower];

//        return sortedValues[lower] + (sortedValues[upper] - sortedValues[lower]) * (rank - lower);
//    }

//    /// <summary>
//    /// Groups places by a coarse geographic grid cell plus primary type, so "hidden" is judged relative to
//    /// similar nearby places - a 50-review cafe in a small town and a 50-review cafe in a dense city center
//    /// should not be scored as equally obscure.
//    /// </summary>
//    private static string BuildGroupKey(PlaceCandidate place, double gridSizeDegrees)
//    {
//        var latCell = Math.Floor(place.Latitude / gridSizeDegrees);
//        var lngCell = Math.Floor(place.Longitude / gridSizeDegrees);
//        return $"{place.PrimaryType}:{latCell}:{lngCell}";
//    }

//    /// <summary>
//    /// Review counts follow a power-law distribution (a handful of places have thousands of reviews, most
//    /// have a few dozen), so a log scale is used instead of linear min-max scaling - otherwise one viral
//    /// landmark in the comparison group would flatten every other score toward 0.
//    /// </summary>
//    private static double NormalizeReviewCount(int reviewCount, int comparisonMax)
//    {
//        if (comparisonMax <= 0) return 0;

//        var normalized = Math.Log(reviewCount + 1) / Math.Log(comparisonMax + 1);
//        return Math.Clamp(normalized, 0, 1);
//    }

//    private static double NormalizeRating(double? rating, double minRating)
//    {
//        if (rating is null) return 0;

//        const double maxRating = 5.0;
//        if (maxRating <= minRating) return 1;

//        var normalized = (rating.Value - minRating) / (maxRating - minRating);
//        return Math.Clamp(normalized, 0, 1);
//    }

//    // ============================================================
//    //  Private helpers: community place merge
//    // ============================================================

//    /// <summary>
//    /// Verified community submissions inside the searched radius, newest first.
//    ///
//    /// These live in recommended_places, NOT in hidden_place_cache, and that separation is
//    /// deliberate: the cache is deleted and rewritten wholesale on every refresh, so a user
//    /// submission stored there would be destroyed by the next Google fetch that touched its cell.
//    /// The two are merged here, at read time, and nowhere else.
//    ///
//    /// Failures are swallowed. The Google half of the search has already succeeded by this point,
//    /// and losing the community additions is much better than losing everything.
//    /// </summary>
//    private async Task<List<HiddenPlaceResponseItemDto>> GetVerifiedCommunityPlacesAsync(
//        DiscoverHiddenPlaceRequestDto request)
//    {
//        try
//        {
//            // Already filtered to status VERIFIED and ordered newest-first by the repository.
//            var published = await _repository.GetPublishedPlacesAsync();

//            return published
//                // A submission without a place row cannot be placed on a map at all. It should not
//                // be possible, but a null here would crash the whole search rather than lose one pin.
//                .Where(p => p.Place != null)
//                .Select(p => new
//                {
//                    Place = p,
//                    Latitude = p.Place!.Latitude,
//                    Longitude = p.Place!.Longitude
//                })
//                .Where(x => SearchGridPlanner.DistanceMeters(
//                    request.Latitude, request.Longitude, x.Latitude, x.Longitude) <= request.RadiusMeters)
//                .Select(x => MapCommunityToResponseDto(x.Place, x.Latitude, x.Longitude))
//                .ToList();
//        }
//        catch (Exception ex)
//        {
//            _logger.LogError(ex, "Could not load community places; returning Google results only.");
//            return new List<HiddenPlaceResponseItemDto>();
//        }
//    }

//    private static HiddenPlaceResponseItemDto MapCommunityToResponseDto(
//        PlaceSubmission place, double latitude, double longitude) => new()
//    {
//        // The submission id stands in for a Google place id. It is a GUID, so it cannot collide with
//        // a real one, and the client only ever uses this field as an identity key.
//        PlaceId = place.SubmissionId,
//        Name = place.Place!.Name,
//        PrimaryType = MapCategoryToPlaceType(place.Place!.PrimaryType),
//        Latitude = latitude,
//        Longitude = longitude,

//        // Left empty rather than faked. Rating, review count, HiddenScore and FormattedAddress all
//        // describe how many strangers on Google have been somewhere - a question a community
//        // submission has no answer to. Source is what tells the client to stop reading them.
//        FormattedAddress = null,
//        Rating = null,
//        UserRatingCount = 0,
//        HiddenScore = 0,

//        Source = HiddenPlaceSource.Community
//    };

//    /// <summary>
//    /// Translates a submission's category ("Scenic Point") into the Places API type string the app
//    /// already has an icon for ("scenic_spot"), so a community pin looks like every other pin of its
//    /// kind instead of falling through to a generic marker.
//    ///
//    /// Keep in step with RecommendedPlaceCategories.All - an unlisted category is not an error, it
//    /// just gets the fallback icon.
//    /// </summary>
//    private static string MapCategoryToPlaceType(string category) => category switch
//    {
//        RecommendedPlaceCategories.Cafe => "cafe",
//        RecommendedPlaceCategories.Restaurant => "restaurant",
//        RecommendedPlaceCategories.ScenicPoint => "scenic_spot",
//        RecommendedPlaceCategories.HistoricalSite => "historical_landmark",
//        RecommendedPlaceCategories.NatureAndParks => "park",
//        RecommendedPlaceCategories.ShoppingAndMarket => "market",
//        _ => "tourist_attraction"
//    };

//    // ============================================================
//    //  Private helpers: Google Places fetching
//    // ============================================================

//    /// <summary>
//    /// Fetches every bucket that missed the cache, bounded to MaxConcurrentFetches at a time. A
//    /// bucket whose Google Places call fails is logged and skipped rather than failing the whole
//    /// request - a partial result set beats no result set. Only touches HttpClient here, never the
//    /// DbContext, so this is safe to run concurrently (DbContext itself is NOT thread-safe, which is
//    /// why the cache write in DiscoverHiddenPlacesAsync happens afterwards, sequentially).
//    /// </summary>
//    private async Task<Dictionary<string, List<HiddenPlaceEntity>>> FetchBucketsAsync(
//        List<SearchBucket> bucketsToFetch, int maxResultCount, CancellationToken cancellationToken)
//    {
//        var result = new Dictionary<string, List<HiddenPlaceEntity>>();
//        if (bucketsToFetch.Count == 0)
//        {
//            return result;
//        }

//        using var throttle = new SemaphoreSlim(MaxConcurrentFetches);

//        var tasks = bucketsToFetch.Select(async bucket =>
//        {
//            await throttle.WaitAsync(cancellationToken);
//            try
//            {
//                var candidates = await _placesApiClient.SearchNearbyAsync(
//                    bucket.CenterLatitude,
//                    bucket.CenterLongitude,
//                    bucket.RadiusMeters,
//                    new[] { bucket.PlaceType },
//                    maxResultCount,
//                    cancellationToken);

//                return (bucket.BucketKey, Entities: candidates.Select(ToEntity).ToList());
//            }
//            catch (Exception ex)
//            {
//                _logger.LogWarning(ex, "Places API fetch failed for bucket {BucketKey} - skipping it.", bucket.BucketKey);
//                return (bucket.BucketKey, Entities: new List<HiddenPlaceEntity>());
//            }
//            finally
//            {
//                throttle.Release();
//            }
//        });

//        var completed = await Task.WhenAll(tasks);
//        foreach (var (bucketKey, entities) in completed)
//        {
//            result[bucketKey] = entities;
//        }
//        return result;
//    }



//    // Instance method (not static) because it needs PassesQualityGate to tag each row with
//    // whether it passes the quality gate - see HiddenPlace.PassedQualityGate's doc comment for why this
//    // is the absolute/stage-1 check only, not the final relative HiddenScore.
//    private HiddenPlaceEntity ToEntity(PlaceCandidate place) => new()
//    {
//        PlaceId = place.PlaceId,
//        Name = place.Name,
//        PrimaryType = place.PrimaryType,
//        Latitude = place.Latitude,
//        Longitude = place.Longitude,
//        Rating = place.Rating,
//        UserRatingCount = place.UserRatingCount,
//        PriceLevel = place.PriceLevel,
//        BusinessStatus = place.BusinessStatus,
//        FormattedAddress = place.FormattedAddress,
//        GoogleMapsUri = place.GoogleMapsUri,
//        WebsiteUri = place.WebsiteUri,
//        NationalPhoneNumber = place.NationalPhoneNumber,
//        PhotosJson = place.PhotosJson,
//        RegularOpeningHoursJson = place.RegularOpeningHoursJson,
//        AddressComponentsJson = place.AddressComponentsJson,
//        ViewportJson = place.ViewportJson,
//        GoogleMapsLinksJson = place.GoogleMapsLinksJson,
//        AccessibilityOptionsJson = place.AccessibilityOptionsJson,
//        ContainingPlacesJson = place.ContainingPlacesJson,
//        PureServiceAreaBusiness = place.PureServiceAreaBusiness,
//        OpeningDate = place.OpeningDate,
//        PrimaryTypeDisplayName = place.PrimaryTypeDisplayName,
//        ShortFormattedAddress = place.ShortFormattedAddress,
//        PassedQualityGate = PassesQualityGate(place)
//    };

//    private static PlaceCandidate ToPlaceCandidate(HiddenPlaceEntity entity) => new()
//    {
//        PlaceId = entity.PlaceId,
//        Name = entity.Name,
//        PrimaryType = entity.PrimaryType,
//        Latitude = entity.Latitude,
//        Longitude = entity.Longitude,
//        Rating = entity.Rating,
//        UserRatingCount = entity.UserRatingCount,
//        PriceLevel = entity.PriceLevel,
//        BusinessStatus = entity.BusinessStatus,
//        FormattedAddress = entity.FormattedAddress,
//        GoogleMapsUri = entity.GoogleMapsUri,
//        WebsiteUri = entity.WebsiteUri,
//        NationalPhoneNumber = entity.NationalPhoneNumber,
//        PhotosJson = entity.PhotosJson,
//        RegularOpeningHoursJson = entity.RegularOpeningHoursJson,
//        AddressComponentsJson = entity.AddressComponentsJson,
//        ViewportJson = entity.ViewportJson,
//        GoogleMapsLinksJson = entity.GoogleMapsLinksJson,
//        AccessibilityOptionsJson = entity.AccessibilityOptionsJson,
//        ContainingPlacesJson = entity.ContainingPlacesJson,
//        PureServiceAreaBusiness = entity.PureServiceAreaBusiness,
//        OpeningDate = entity.OpeningDate,
//        PrimaryTypeDisplayName = entity.PrimaryTypeDisplayName,
//        ShortFormattedAddress = entity.ShortFormattedAddress
//    };

//    private static HiddenPlaceResponseItemDto MapToResponseDto(
//        HiddenPlaceResult result,
//        IReadOnlyDictionary<string, PlacePhotoInfo> photos)
//    {
//        // Absent rather than null when a place has no picture - see IPlacePhotoService.
//        photos.TryGetValue(result.Place.PlaceId, out var photo);

//        return new HiddenPlaceResponseItemDto
//        {
//            PlaceId = result.Place.PlaceId,
//            Name = result.Place.Name,
//            PrimaryType = result.Place.PrimaryType,
//            Latitude = result.Place.Latitude,
//            Longitude = result.Place.Longitude,
//            Rating = result.Place.Rating,
//            UserRatingCount = result.Place.UserRatingCount,
//            PriceLevel = result.Place.PriceLevel,
//            FormattedAddress = result.Place.FormattedAddress,
//            GoogleMapsUri = result.Place.GoogleMapsUri,
//            WebsiteUri = result.Place.WebsiteUri,
//            NationalPhoneNumber = result.Place.NationalPhoneNumber,
//            PhotosJson = result.Place.PhotosJson,
//            RegularOpeningHoursJson = result.Place.RegularOpeningHoursJson,
//            AddressComponentsJson = result.Place.AddressComponentsJson,
//            ViewportJson = result.Place.ViewportJson,
//            GoogleMapsLinksJson = result.Place.GoogleMapsLinksJson,
//            AccessibilityOptionsJson = result.Place.AccessibilityOptionsJson,
//            ContainingPlacesJson = result.Place.ContainingPlacesJson,
//            PureServiceAreaBusiness = result.Place.PureServiceAreaBusiness,
//            OpeningDate = result.Place.OpeningDate,
//            PrimaryTypeDisplayName = result.Place.PrimaryTypeDisplayName,
//            ShortFormattedAddress = result.Place.ShortFormattedAddress,
//            HiddenScore = result.HiddenScore,

//            // The two halves the blended score is made of. Carried through so the client can explain a
//            // ranking instead of just presenting it - see HiddenPlaceResponseItemDto.ObscurityScore.
//            // PopularityNorm is inverted here (1 - x) so every score in the DTO reads "higher = more hidden".
//            ObscurityScore = 1 - result.PopularityNorm,
//            QualityScore = result.RatingNorm,

//            PhotoUrl = photo?.Url,
//            PhotoAttribution = photo?.Attribution
//        };
//    }
//}

using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

/// <summary>
/// Core "冷门度" (hidden-gem) discovery algorithm.
///
/// Runs in three stages:
///   1) Quality gate  - drop places that are closed, unrated/under-reviewed, or a known chain brand.
///                       These aren't "hidden gems" - they're untrustworthy data points, or inherently
///                       not hidden regardless of how few reviews they have locally.
///   2) The ceiling   - drop places that are among the best known of their own type in this search. This
///                       is what enforces "lots of reviews means not hidden"; the cutoff is a percentile
///                       rather than a fixed count, because the count that means "famous" differs by type
///                       and by area. See BuildReviewCeilings.
///   3) Scoring       - rank whatever is left by how few people know about them (review count, compared
///                       against similar nearby places rather than a global pool) balanced against
///                       how good they actually are (rating). Optionally trimmed at the bottom by
///                       MinHiddenScore, which is off by default - see that setting for why.
///
/// This class is pure computation: it takes already-fetched Places API data in and returns a ranked
/// list out. It knows nothing about HTTP calls or persistence, which keeps it easy to unit test -
/// fetching from Google Places API and saving results belong in a separate client/repository that
/// calls into this service (e.g. via IHiddenPlaceService in the Facade folder).
/// </summary>
public class DiscoverHiddenPlaceService : IDiscoverHiddenPlaceService
{
    public IReadOnlyList<HiddenPlaceResult> Discover(
        IEnumerable<PlaceCandidate> candidates,
        DiscoverHiddenPlaceOptions? options = null)
    {
        options ??= new DiscoverHiddenPlaceOptions();

        // Two pools, and keeping them apart is load-bearing.
        //
        // referencePool is what scoring COMPARES AGAINST: every trustworthy place, deliberately including
        // the well-known ones the ceiling will stop us returning. It answers "how well-known do places of
        // this type get around here?" - a fact about the area, which must not change just because the app
        // has decided not to show the well-known ones. The famous museum down the road is exactly the
        // yardstick that makes a quiet one look obscure.
        //
        // Scoring off the returned set instead is self-referential: excluding popular places lowers each
        // group's maximum, which is the divisor in NormalizeReviewCount, which inflates every remaining
        // place's popularityNorm and so deflates every HiddenScore. Measured on a real KL search, applying
        // a 500 ceiling that way pushed the top score from 0.751 down to 0.626 and cut the surviving
        // results from 54 to 13 - the two settings multiplied instead of acting independently.
        var referencePool = candidates.Where(place => PassesBaseQualityChecks(place, options)).ToList();
        if (referencePool.Count == 0)
        {
            return Array.Empty<HiddenPlaceResult>();
        }

        // survivors is what actually gets scored and returned: everything trustworthy that isn't among the
        // best-known of its own type. See BuildReviewCeilings for why the cutoff is a percentile per type
        // rather than one review count for everything.
        var reviewCeilings = BuildReviewCeilings(referencePool, options);
        var survivors = referencePool
            .Where(place => place.UserRatingCount <= reviewCeilings.For(place.PrimaryType))
            .ToList();
        if (survivors.Count == 0)
        {
            return Array.Empty<HiddenPlaceResult>();
        }

        // Fallback comparison pool for local groups that are too small to judge fairly on their own.
        var globalMaxReviewCount = referencePool.Max(p => p.UserRatingCount);

        var localGroups = referencePool
            .GroupBy(p => BuildGroupKey(p, options.LocalGroupGridSizeDegrees))
            .ToDictionary(g => g.Key, g => g.ToList());

        var results = new List<HiddenPlaceResult>(survivors.Count);

        foreach (var place in survivors)
        {
            var group = localGroups[BuildGroupKey(place, options.LocalGroupGridSizeDegrees)];

            var comparisonMax = group.Count >= options.MinGroupSizeForLocalComparison
                ? group.Max(p => p.UserRatingCount)
                : globalMaxReviewCount;

            var popularityNorm = NormalizeReviewCount(place.UserRatingCount, comparisonMax);
            var ratingNorm = NormalizeRating(place.Rating, options.MinRating);

            var hiddenScore =
                options.PopularityWeight * (1 - popularityNorm) +
                options.QualityWeight * ratingNorm;

            results.Add(new HiddenPlaceResult
            {
                Place = place,
                HiddenScore = Math.Clamp(hiddenScore, 0, 1),
                PopularityNorm = popularityNorm,
                RatingNorm = ratingNorm
            });
        }

        // Optional bottom trim. The ceiling above already removed the well-known places, so this is off
        // (0) by default - see DiscoverHiddenPlaceOptions.MinHiddenScore for why it is a poor primary
        // filter and what it is still useful for.
        //
        // The two ThenBy keys are what make the ranking reproducible, not just sorted. LINQ's OrderBy is a
        // stable sort, so ties keep their INPUT order - and the input is whatever order MySQL handed the
        // cached rows back in, which is unspecified without an ORDER BY. Ties are not a corner case here:
        // HiddenScore blends two signals, so genuinely different places collide on the same value (a
        // 25-review museum and a 1663-review temple both scored 0.411 on a real KL search). Without these,
        // running the same search twice can hand back the same places in a different order.
        //
        // UserRatingCount first because it is the tie-break a user would expect: same score, fewer people
        // know about it, so it is the more "hidden" of the two. PlaceId last purely for determinism - it
        // carries no meaning, it just guarantees a total order so the output is a function of the input.
        return results
            .Where(r => r.HiddenScore >= options.MinHiddenScore)
            .OrderByDescending(r => r.HiddenScore)
            .ThenBy(r => r.Place.UserRatingCount)
            .ThenBy(r => r.Place.PlaceId, StringComparer.Ordinal)
            .ToList();
    }

    /// <summary>
    /// Everything about a candidate that can be judged from its own fields alone - business status, rating,
    /// the review-count floor, the absolute review-count ceiling, and the name. Exposed publicly (rather
    /// than kept as a private filter inside Discover) so callers that persist raw Places API data - see
    /// HiddenPlaceService writing to the hidden_place_cache table - can record whether a place would pass
    /// without running the full Discover pipeline.
    ///
    /// This is deliberately NOT the whole of what Discover applies. The percentile ceiling that does most
    /// of the "too well-known" work is derived from the other places in the same search (see
    /// BuildReviewCeilings), so it cannot be evaluated one place at a time and is not included here. A row
    /// stamped as passing this gate is therefore saying "trustworthy, and not famous in absolute terms" -
    /// not "this would be returned to a user".
    /// </summary>
    public bool PassesQualityGate(PlaceCandidate place, DiscoverHiddenPlaceOptions? options = null)
    {
        options ??= new DiscoverHiddenPlaceOptions();

        return PassesBaseQualityChecks(place, options)
               && place.UserRatingCount <= options.MaxUserRatingCount;
    }

    /// <summary>
    /// Everything the quality gate checks EXCEPT the MaxUserRatingCount ceiling: is this a real, open,
    /// independently-run place with enough reviews to be worth trusting?
    ///
    /// Split out because the two questions are asked at different moments. "Is this data trustworthy?"
    /// decides who belongs in the comparison pool HiddenScore is measured against; "is this too well-known
    /// to show?" decides who gets returned. A famous museum belongs in the first group and not the second.
    /// See the comment on referencePool in Discover for what went wrong when both were one filter.
    /// </summary>
    private static bool PassesBaseQualityChecks(PlaceCandidate place, DiscoverHiddenPlaceOptions options)
    {
        if (!options.AllowedBusinessStatuses.Contains(place.BusinessStatus))
            return false;

        if (place.Rating is null || place.Rating < options.MinRating)
            return false;

        if (place.UserRatingCount < options.MinUserRatingCount)
            return false;

        if (options.ChainBrandKeywords.Any(keyword =>
                place.Name.Contains(keyword, StringComparison.OrdinalIgnoreCase)))
            return false;

        return true;
    }

    /// <summary>The review-count ceiling that applies to each primary type in one search.</summary>
    private sealed class ReviewCeilings
    {
        private readonly Dictionary<string, double> _byPrimaryType;
        private readonly double _fallback;

        public ReviewCeilings(Dictionary<string, double> byPrimaryType, double fallback)
        {
            _byPrimaryType = byPrimaryType;
            _fallback = fallback;
        }

        public double For(string primaryType) =>
            _byPrimaryType.TryGetValue(primaryType, out var ceiling) ? ceiling : _fallback;
    }

    /// <summary>
    /// Works out, per primary type, how many reviews is "too many to still be hidden" for THIS search.
    ///
    /// The cutoff is a percentile of what the search actually found rather than a constant, because the
    /// number that means "well-known" is not portable. It differs by type - in sampled KL data the 60th
    /// percentile was 129 reviews for coffee_shop but 1066 for museum, because museums simply collect more
    /// reviews than cafes - and it differs by area, since a count that marks a place as famous downtown can
    /// exceed everything in a small town. Deriving it from the current result set handles both without any
    /// per-city or per-type table to maintain.
    ///
    /// Types with fewer than MinGroupSizeForPercentileCeiling members fall back to the percentile over the
    /// whole pool: a percentile across two or three places is noise, and if those few happen to be famous it
    /// would compute a ceiling high enough to admit all of them. Every ceiling is then clamped by the
    /// absolute MaxUserRatingCount, which covers the case where a whole search is landmarks and even the
    /// least famous 60% of them are not hidden by any reasonable reading.
    /// </summary>
    private static ReviewCeilings BuildReviewCeilings(
        IReadOnlyList<PlaceCandidate> referencePool, DiscoverHiddenPlaceOptions options)
    {
        double absoluteCeiling = options.MaxUserRatingCount;

        double CeilingFor(IEnumerable<PlaceCandidate> places) => Math.Min(
            Percentile(places.Select(p => p.UserRatingCount).OrderBy(n => n).ToList(),
                       options.MaxUserRatingPercentile),
            absoluteCeiling);

        var byPrimaryType = referencePool
            .GroupBy(p => p.PrimaryType)
            .Where(g => g.Count() >= options.MinGroupSizeForPercentileCeiling)
            .ToDictionary(g => g.Key, g => CeilingFor(g));

        return new ReviewCeilings(byPrimaryType, CeilingFor(referencePool));
    }

    /// <summary>
    /// Linear-interpolated percentile over an ALREADY SORTED ascending list. Interpolated rather than
    /// nearest-rank so that small groups - which is most of them, since a search rarely returns many places
    /// of any one type - don't make the ceiling jump between two members' review counts.
    /// </summary>
    private static double Percentile(IReadOnlyList<int> sortedValues, double percentile)
    {
        if (sortedValues.Count == 0) return 0;
        if (sortedValues.Count == 1) return sortedValues[0];

        var rank = (sortedValues.Count - 1) * Math.Clamp(percentile, 0, 1);
        var lower = (int)Math.Floor(rank);
        var upper = (int)Math.Ceiling(rank);
        if (lower == upper) return sortedValues[lower];

        return sortedValues[lower] + (sortedValues[upper] - sortedValues[lower]) * (rank - lower);
    }

    /// <summary>
    /// Groups places by a coarse geographic grid cell plus primary type, so "hidden" is judged relative to
    /// similar nearby places - a 50-review cafe in a small town and a 50-review cafe in a dense city center
    /// should not be scored as equally obscure.
    /// </summary>
    private static string BuildGroupKey(PlaceCandidate place, double gridSizeDegrees)
    {
        var latCell = Math.Floor(place.Latitude / gridSizeDegrees);
        var lngCell = Math.Floor(place.Longitude / gridSizeDegrees);
        return $"{place.PrimaryType}:{latCell}:{lngCell}";
    }

    /// <summary>
    /// Review counts follow a power-law distribution (a handful of places have thousands of reviews, most
    /// have a few dozen), so a log scale is used instead of linear min-max scaling - otherwise one viral
    /// landmark in the comparison group would flatten every other score toward 0.
    /// </summary>
    private static double NormalizeReviewCount(int reviewCount, int comparisonMax)
    {
        if (comparisonMax <= 0) return 0;

        var normalized = Math.Log(reviewCount + 1) / Math.Log(comparisonMax + 1);
        return Math.Clamp(normalized, 0, 1);
    }

    private static double NormalizeRating(double? rating, double minRating)
    {
        if (rating is null) return 0;

        const double maxRating = 5.0;
        if (maxRating <= minRating) return 1;

        var normalized = (rating.Value - minRating) / (maxRating - minRating);
        return Math.Clamp(normalized, 0, 1);
    }
    private readonly IHiddenPlaceRepository _repository;
    private readonly ILogger<DiscoverHiddenPlaceService> _logger;

    public DiscoverHiddenPlaceService(IHiddenPlaceRepository repository, ILogger<DiscoverHiddenPlaceService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<List<RecommendedPlaceSummaryDto>> GetPublishedPlacesAsync()
    {
        var places = await _repository.GetPublishedPlacesAsync();

        _logger.LogInformation("Loaded {Count} published recommended places.", places.Count);
        return places
            .OrderByDescending(p => p.CreatedAt)
            .Select(ToSummaryDto)
            .ToList();
    }

    private static RecommendedPlaceSummaryDto ToSummaryDto(PlaceSubmission p) => new()
    {
        SubmissionId = p.SubmissionId,
        Name = p.Place!.Name,
        Latitude = (decimal)p.Place.Latitude,
        Longitude = (decimal)p.Place.Longitude,
        PrimaryType = p.Place.PrimaryType,
        Description = p.Place.Description,
        Status = p.Status,
        VerificationCount = p.Verifications.Count,
        RequiredVerifications = RecommendedPlaceThresholds.RequiredVerifications,
        CreatedAt = p.CreatedAt,
        UpdatedAt = p.UpdatedAt,
    };
}