using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;
using ExploreMy.Api.Application.HiddenPlace.HiddenPlaceContribution;
using ExploreMy.Api.Application.HiddenPlace.PlacePhotos;
using ExploreMy.Api.Application.HiddenPlace.Review;
using ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.HiddenPlace;
using HiddenPlaceEntity = ExploreMy.Api.Domain.Entities.HiddenPlace;
using System.Text.Json;

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
    private readonly IHiddenPlaceContributionService _contribution;
    private readonly IPlacePhotoService _placePhotoService;
    private readonly IHiddenPlaceSuppressionRepository _suppressionRepository;
    private readonly IReviewService _reviewService;
    private readonly IReviewPhotoRepository _reviewPhotoRepository;
    private readonly IReviewRepository _reviewRepository;

    public HiddenPlaceService(
        IPlacesApiClient placesApiClient,
        IHiddenPlaceRepository hiddenPlaceRepository,
        IDiscoverHiddenPlaceService discoverHiddenPlaceService,
        ILogger<HiddenPlaceService> logger,
        IHiddenPlaceContributionService contribution,
        IPlacePhotoService placePhotoService,
        IHiddenPlaceSuppressionRepository suppressionRepository,
        IReviewService reviewService,
        IReviewPhotoRepository reviewPhotoRepository,
        IReviewRepository reviewRepository)
    {
        _reviewService = reviewService;
        _reviewPhotoRepository = reviewPhotoRepository;
        _reviewRepository = reviewRepository;
        _placesApiClient = placesApiClient;
        _hiddenPlaceRepository = hiddenPlaceRepository;
        _discoverHiddenPlaceService = discoverHiddenPlaceService;
        _logger = logger;
        _contribution = contribution;
        _placePhotoService = placePhotoService;
        _suppressionRepository = suppressionRepository;
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
        // legitimately show up in more than one bucket. Neighboring cells' search circles overlap
        // substantially by design (each is its square cell's circumscribed circle, so adjacent circles
        // must intersect for the corners between them to be covered at all - see
        // SearchGridPlanner.CellSearchRadiusMeters), and Google can also return the same place under
        // more than one requested type.
        //
        // Cell membership (SearchGridPlanner.BuildBuckets) is deliberately loose - a cell is included if
        // it merely overlaps the requested radius, not if every place inside it does. So a cell can be a
        // couple of km past the user's radius and still get scanned, and Google can return places from
        // anywhere in that cell's own circle. Without this filter, a place at the far edge of an included
        // cell can end up well outside the radius the user actually asked for (e.g. a 5km search pulling
        // in a place ~9-10km away). This is the exact-distance check that enforces the promised radius.
        // Places the community has reported out of existence - reported by at least HideThreshold
        // separate people, not by one (the repository does the counting). Applied HERE, on the way
        // out, rather than by deleting cache rows: hidden_place_cache is refilled from Google every
        // 30 days, so a deleted row simply comes back and the reports are silently undone. Excluding
        // at read time is the only thing a refresh cannot overwrite.
        var suppressedPlaceIds = await _suppressionRepository.GetSuppressedPlaceIdsAsync();

        var candidates = freshCache.Values.SelectMany(v => v)
            .Concat(fetched.Values.SelectMany(v => v))
            .GroupBy(e => e.PlaceId)
            .Select(g => ToPlaceCandidate(g.First()))
            .Where(c => !suppressedPlaceIds.Contains(c.PlaceId))
            .Where(c => SearchGridPlanner.DistanceMeters(
                request.Latitude, request.Longitude, c.Latitude, c.Longitude) <= request.RadiusMeters)
            .ToList();

        // Our own reviews, folded into the candidates BEFORE scoring. They belong to the algorithm's
        // inputs, not to presentation: the quality gate and both halves of HiddenScore read the
        // pooled numbers (PlaceCandidate.EffectiveRating / EffectiveUserRatingCount), so a place our
        // users rate highly can now clear a gate Google's rating alone would have failed.
        await AttachAppReviewStatsAsync(candidates);

        var results = _discoverHiddenPlaceService.Discover(candidates);

        _logger.LogInformation(
            "{SurvivorCount}/{CandidateCount} candidates passed the quality gate near ({Lat}, {Lng}).",
            results.Count, candidates.Count, request.Latitude, request.Longitude);

        // Photos last, and only for the places that actually survived scoring. Doing it earlier would
        // mean paying Google for images of places the quality gate is about to throw away. Never
        // throws - a search without pictures is still a search.
        var photos = await _placePhotoService.EnsurePhotosAsync(
            results.Select(r => r.Place).ToList(), cancellationToken);

        var response = results.Select(result => MapToResponseDto(result, photos)).ToList();

        // Whatever Google had no picture for, our own reviewers may have photographed. Applied
        // after the Google pass and only to what it left empty, so a real place photo always wins.
        await ApplyReviewPhotoFallbackAsync(response);

        // Community picks are appended, never interleaved - now ranked among themselves by
        // CommunityPlaceScorer rather than merely by date. Still not merged into the Google ranking:
        // the two scores land on the same 0-1 scale but are not the same measurement (one is a
        // position in a local review-count distribution, the other is verification plus our own
        // ratings), and sorting them against each other would read as a comparison nobody computed.
        response.AddRange(await GetVerifiedCommunityPlacesAsync(request));

        return response;
    }

    /// <summary>
    /// Community submissions inside the searched radius, newest first - both the verified ones and
    /// those still collecting verifications. Each carries its status out to the client, which draws
    /// the two differently; showing only verified ones meant a person could recommend a place and
    /// then not find it on their own map until five strangers agreed with them.
    ///
    /// These live in recommended_places, NOT in hidden_place_cache, and that separation is
    /// deliberate: the cache is deleted and rewritten wholesale on every refresh, so a user
    /// submission stored there would be destroyed by the next Google fetch that touched its cell.
    /// The two are merged here, at read time, and nowhere else.
    ///
    /// Failures are swallowed. The Google half of the search has already succeeded by this point,
    /// and losing the community additions is much better than losing everything.
    /// </summary>
    private async Task<List<HiddenPlaceResponseItemDto>> GetVerifiedCommunityPlacesAsync(
        DiscoverHiddenPlaceRequestDto request)
    {
        try
        {
            // Ordered newest-first by the repository; UNDER_VOTING included alongside VERIFIED.
            var published = await _hiddenPlaceRepository.GetPublishedPlacesAsync(includeUnderVoting: true);

            var visible = published
                // A submission without a place row cannot be placed on a map at all. It should not
                // be possible, but a null here would crash the whole search rather than lose one pin.
                .Where(p => p.Place != null)
                .Select(p => new
                {
                    Place = p,
                    Latitude = p.Place!.Latitude,
                    Longitude = p.Place!.Longitude
                })
                .Where(x => SearchGridPlanner.DistanceMeters(
                    request.Latitude, request.Longitude, x.Latitude, x.Longitude) <= request.RadiusMeters)
                .ToList();

            // Reported-out community places, excluded the same way Google ones are: at read time.
            //
            // The status flip to REPORTED_CLOSED is the primary mechanism, but it cannot be the only
            // one. It happens inside the report request, so anything that reaches the threshold by a
            // path the report handler did not walk - or that was already VERIFIED when the reports
            // arrived - keeps a publishable status while its suppression rows pile up unread. This
            // check reads those rows and is what the map actually trusts.
            //
            // Matched on RecommendPlaceId, NOT on the DTO's PlaceId: suppression rows store the
            // canonical recommend_place id, while the DTO advertises the submission id (see
            // MapCommunityToResponseDto). Comparing the wrong one silently matches nothing.
            var reportCounts = await _suppressionRepository.GetReportCountsByRecommendedPlaceIdsAsync(
                visible.Select(x => x.Place.RecommendPlaceId).ToList());

            var publishable = visible
                .Where(x => !reportCounts.TryGetValue(x.Place.RecommendPlaceId, out var reports)
                    || reports < RecommendedPlaceThresholds.HideThreshold)
                .ToList();

            // The only rating a community place can have: ours. Google has never heard of it.
            var reviewStats = await LoadCommunityReviewStatsAsync(
                publishable.Select(x => x.Place.RecommendPlaceId).ToList());

            // Ranked among themselves by CommunityPlaceScorer instead of by submission date, which
            // ordered a five-times-verified, well-reviewed place below whatever was typed in most
            // recently. Ties fall back to verification count (more people vouched for it), then to
            // newest, then to the submission id purely so the same search returns the same order.
            var scored = publishable
                .Select(x =>
                {
                    reviewStats.TryGetValue(x.Place.RecommendPlaceId, out var stats);

                    return new
                    {
                        x.Place,
                        x.Latitude,
                        x.Longitude,
                        Score = CommunityPlaceScorer.Score(
                            x.Place.Verifications.Count,
                            stats?.ReviewCount ?? 0,
                            stats?.AverageRating)
                    };
                })
                .OrderByDescending(x => x.Score.HiddenScore)
                .ThenByDescending(x => x.Place.Verifications.Count)
                .ThenByDescending(x => x.Place.CreatedAt)
                .ThenBy(x => x.Place.SubmissionId, StringComparer.Ordinal)
                .ToList();

            var items = scored
                .Select(x => MapCommunityToResponseDto(x.Place, x.Latitude, x.Longitude, x.Score))
                .ToList();

            // The recommender's own photos are already on the DTO by this point; this covers the
            // recommendations submitted without any. Keyed through submission id -> recommend_place
            // id, because those are the two different ids the DTO and a review use for one place.
            await ApplyCommunityReviewPhotoFallbackAsync(
                items,
                publishable.ToDictionary(
                    x => x.Place.SubmissionId,
                    x => x.Place.RecommendPlaceId,
                    StringComparer.Ordinal));

            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not load community places; returning Google results only.");
            return new List<HiddenPlaceResponseItemDto>();
        }
    }

    /// <summary>
    /// Folds our own users' reviews into the candidates, so the algorithm scores every place on what
    /// this app knows about it and not only on what Google does.
    ///
    /// One batched read for the whole search rather than a lookup per place - a dense search carries
    /// hundreds of candidates, and this sits directly in front of the map load.
    ///
    /// Never throws. Without these numbers the Effective* properties fall back to the plain Google
    /// values, so a failure here costs the ranking some nuance and costs the user nothing.
    /// </summary>
    private async Task AttachAppReviewStatsAsync(IReadOnlyList<PlaceCandidate> candidates)
    {
        if (candidates.Count == 0)
        {
            return;
        }

        try
        {
            var stats = await _reviewRepository.GetStatsByGooglePlaceIdsAsync(
                candidates.Select(candidate => candidate.PlaceId).Distinct(StringComparer.Ordinal).ToList());

            if (stats.Count == 0)
            {
                return;
            }

            foreach (var candidate in candidates)
            {
                if (!stats.TryGetValue(candidate.PlaceId, out var stat))
                {
                    continue;
                }

                candidate.AppReviewCount = stat.ReviewCount;
                candidate.AppRating = stat.AverageRating;
            }

            _logger.LogInformation(
                "{Reviewed}/{Candidates} candidate(s) carry reviews written in this app; those are scored on both sources.",
                stats.Count, candidates.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not read our own review stats; scoring this search on Google data alone.");
        }
    }

    /// <summary>
    /// Gives a picture to the Google places that came back without one, borrowed from a review
    /// somebody wrote about that same place.
    ///
    /// Google has no photo for a large share of what this endpoint returns - obscurity is the whole
    /// selection criterion, and obscure places are exactly the ones nobody has photographed for
    /// Google. Those cards showed a placeholder even when one of our own users had been there and
    /// posted pictures with their review; the pictures were already in our bucket.
    ///
    /// Only fills gaps. A place with a Google photo keeps it, because that image was chosen (and
    /// paid for) as the place's own picture, while a review photo is one visitor's snapshot.
    ///
    /// Never throws, for the same reason EnsurePhotosAsync doesn't: the search has already
    /// succeeded by this point, and a missing picture must not turn it into an error.
    /// </summary>
    private async Task ApplyReviewPhotoFallbackAsync(List<HiddenPlaceResponseItemDto> items)
    {
        var missing = items.Where(item => string.IsNullOrWhiteSpace(item.PhotoUrl)).ToList();
        if (missing.Count == 0)
        {
            return;
        }

        try
        {
            var covers = await _reviewPhotoRepository.GetCoverPhotosByGooglePlaceIdsAsync(
                missing.Select(item => item.PlaceId).ToList());

            var filled = 0;
            foreach (var item in missing)
            {
                if (!covers.TryGetValue(item.PlaceId, out var cover))
                {
                    continue;
                }

                item.PhotoUrl = cover.PhotoUrl;
                item.PhotoAttribution = cover.Attribution;
                filled++;
            }

            _logger.LogInformation(
                "{Filled}/{Missing} place(s) without a Google photo got one from a user review.",
                filled, missing.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not read review photos; those places stay without a picture.");
        }
    }

    /// <summary>
    /// Our own review counts and averages for a batch of community places, keyed by
    /// recommend_place_id.
    ///
    /// Swallows failures and returns an empty map instead of letting them reach the caller's catch,
    /// which would drop every community place from the search. Without stats each place still
    /// scores - CommunityPlaceScorer falls back to its verification count - so the cost of a failure
    /// here is a coarser ordering, not a missing section.
    /// </summary>
    private async Task<Dictionary<string, PlaceReviewStats>> LoadCommunityReviewStatsAsync(
        IReadOnlyCollection<string> recommendPlaceIds)
    {
        try
        {
            return await _reviewRepository.GetStatsByRecommendPlaceIdsAsync(recommendPlaceIds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not read review stats for community places; ranking them on verifications alone.");
            return new Dictionary<string, PlaceReviewStats>(StringComparer.Ordinal);
        }
    }

    /// <summary>
    /// Same fallback as the Google one, for community places recommended without a photo.
    ///
    /// Separate method because the two halves identify a place differently: a community DTO's
    /// PlaceId is the SUBMISSION id, while a review stores the canonical recommend_place id, so the
    /// lookup has to go through <paramref name="recommendPlaceIdBySubmissionId"/>. This is the same
    /// id mismatch that silently broke the suppression filter.
    ///
    /// Has its own try/catch rather than relying on the caller's: GetVerifiedCommunityPlacesAsync
    /// answers a failure by dropping EVERY community place from the search, which is far too high a
    /// price for a missing picture.
    /// </summary>
    private async Task ApplyCommunityReviewPhotoFallbackAsync(
        List<HiddenPlaceResponseItemDto> items,
        IReadOnlyDictionary<string, string> recommendPlaceIdBySubmissionId)
    {
        var missing = items.Where(item => string.IsNullOrWhiteSpace(item.PhotoUrl)).ToList();
        if (missing.Count == 0)
        {
            return;
        }

        try
        {
            var wanted = missing
                .Select(item => recommendPlaceIdBySubmissionId.TryGetValue(item.PlaceId, out var id) ? id : null)
                .Where(id => !string.IsNullOrWhiteSpace(id))
                .Select(id => id!)
                .ToList();

            if (wanted.Count == 0)
            {
                return;
            }

            var covers = await _reviewPhotoRepository.GetCoverPhotosByRecommendPlaceIdsAsync(wanted);
            if (covers.Count == 0)
            {
                return;
            }

            var filled = 0;
            foreach (var item in missing)
            {
                if (!recommendPlaceIdBySubmissionId.TryGetValue(item.PlaceId, out var recommendPlaceId)
                    || !covers.TryGetValue(recommendPlaceId, out var cover))
                {
                    continue;
                }

                item.PhotoUrl = cover.PhotoUrl;
                item.PhotoAttribution = cover.Attribution;
                filled++;
            }

            _logger.LogInformation(
                "{Filled}/{Missing} community place(s) without a submitted photo got one from a user review.",
                filled, missing.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not read review photos for community places; they stay without a picture.");
        }
    }

    private static HiddenPlaceResponseItemDto MapCommunityToResponseDto(
    PlaceSubmission place, double latitude, double longitude, CommunityPlaceScore score)
    {
        string? photoUrl = null;

        if (!string.IsNullOrWhiteSpace(place.Place!.PhotosJson))
        {
            try
            {
                var photos = JsonSerializer.Deserialize<List<string>>(
                    place.Place.PhotosJson);

                photoUrl = photos?.FirstOrDefault();
            }
            catch (JsonException)
            {
                // Invalid PhotosJson - leave PhotoUrl as null.
            }
        }

        return new HiddenPlaceResponseItemDto
        {
            PlaceId = place.SubmissionId,
            Name = place.Place.Name,
            PrimaryType = MapCategoryToPlaceType(place.Place.PrimaryType),
            Latitude = latitude,
            Longitude = longitude,

            FormattedAddress = null,
            Rating = null,
            UserRatingCount = 0,

            // Scored, not zeroed. These used to be hard 0, which is why community places could only
            // be ordered by date: there was nothing else to sort on. CommunityPlaceScorer answers
            // the same question from what a recommendation does have - verifications, and our own
            // reviews. Comparable in scale to a Google HiddenScore, but not the same measurement,
            // which is why these are still appended after the ranked list rather than merged in.
            HiddenScore = score.HiddenScore,
            ObscurityScore = score.ObscurityScore,
            QualityScore = score.QualityScore,

            // Community photos are stored as our own Supabase URLs.
            PhotosJson = place.Place.PhotosJson,
            PhotoUrl = photoUrl,
            PhotoAttribution = null,

            Source = HiddenPlaceSource.Community,
            CommunityStatus = place.Status
        };
    }

    /// <summary>
    /// Translates a submission's category ("Scenic Point") into the Places API type string the app
    /// already has an icon for ("scenic_spot"), so a community pin looks like every other pin of its
    /// kind instead of falling through to a generic marker.
    ///
    /// Keep in step with RecommendedPlaceCategories.All - an unlisted category is not an error, it
    /// just gets the fallback icon.
    /// </summary>
    private static string MapCategoryToPlaceType(string category) => category switch
    {
        RecommendedPlaceCategories.Cafe => "cafe",
        RecommendedPlaceCategories.Restaurant => "restaurant",
        RecommendedPlaceCategories.ScenicPoint => "scenic_spot",
        RecommendedPlaceCategories.HistoricalSite => "historical_landmark",
        RecommendedPlaceCategories.NatureAndParks => "park",
        RecommendedPlaceCategories.ShoppingAndMarket => "market",
        _ => "tourist_attraction"
    };

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
        FormattedAddress = place.FormattedAddress,
        GoogleMapsUri = place.GoogleMapsUri,
        WebsiteUri = place.WebsiteUri,
        NationalPhoneNumber = place.NationalPhoneNumber,
        PhotosJson = place.PhotosJson,
        RegularOpeningHoursJson = place.RegularOpeningHoursJson,
        AddressComponentsJson = place.AddressComponentsJson,
        ViewportJson = place.ViewportJson,
        GoogleMapsLinksJson = place.GoogleMapsLinksJson,
        AccessibilityOptionsJson = place.AccessibilityOptionsJson,
        ContainingPlacesJson = place.ContainingPlacesJson,
        PureServiceAreaBusiness = place.PureServiceAreaBusiness,
        OpeningDate = place.OpeningDate,
        PrimaryTypeDisplayName = place.PrimaryTypeDisplayName,
        ShortFormattedAddress = place.ShortFormattedAddress,
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
        BusinessStatus = entity.BusinessStatus,
        FormattedAddress = entity.FormattedAddress,
        GoogleMapsUri = entity.GoogleMapsUri,
        WebsiteUri = entity.WebsiteUri,
        NationalPhoneNumber = entity.NationalPhoneNumber,
        PhotosJson = entity.PhotosJson,
        RegularOpeningHoursJson = entity.RegularOpeningHoursJson,
        AddressComponentsJson = entity.AddressComponentsJson,
        ViewportJson = entity.ViewportJson,
        GoogleMapsLinksJson = entity.GoogleMapsLinksJson,
        AccessibilityOptionsJson = entity.AccessibilityOptionsJson,
        ContainingPlacesJson = entity.ContainingPlacesJson,
        PureServiceAreaBusiness = entity.PureServiceAreaBusiness,
        OpeningDate = entity.OpeningDate,
        PrimaryTypeDisplayName = entity.PrimaryTypeDisplayName,
        ShortFormattedAddress = entity.ShortFormattedAddress
    };

    private static HiddenPlaceResponseItemDto MapToResponseDto(
        HiddenPlaceResult result,
        IReadOnlyDictionary<string, PlacePhotoInfo> photos)
    {
        // Absent rather than null when a place has no picture - see IPlacePhotoService.
        photos.TryGetValue(result.Place.PlaceId, out var photo);

        return new HiddenPlaceResponseItemDto
        {
            PlaceId = result.Place.PlaceId,
            Name = result.Place.Name,
            PrimaryType = result.Place.PrimaryType,
            Latitude = result.Place.Latitude,
            Longitude = result.Place.Longitude,
            Rating = result.Place.Rating,
            UserRatingCount = result.Place.UserRatingCount,
            PriceLevel = result.Place.PriceLevel,
            FormattedAddress = result.Place.FormattedAddress,
            GoogleMapsUri = result.Place.GoogleMapsUri,
            WebsiteUri = result.Place.WebsiteUri,
            NationalPhoneNumber = result.Place.NationalPhoneNumber,
            PhotosJson = result.Place.PhotosJson,
            RegularOpeningHoursJson = result.Place.RegularOpeningHoursJson,
            AddressComponentsJson = result.Place.AddressComponentsJson,
            ViewportJson = result.Place.ViewportJson,
            GoogleMapsLinksJson = result.Place.GoogleMapsLinksJson,
            AccessibilityOptionsJson = result.Place.AccessibilityOptionsJson,
            ContainingPlacesJson = result.Place.ContainingPlacesJson,
            PureServiceAreaBusiness = result.Place.PureServiceAreaBusiness,
            OpeningDate = result.Place.OpeningDate,
            PrimaryTypeDisplayName = result.Place.PrimaryTypeDisplayName,
            ShortFormattedAddress = result.Place.ShortFormattedAddress,
            HiddenScore = result.HiddenScore,

            // The two halves the blended score is made of. Carried through so the client can explain a
            // ranking instead of just presenting it - see HiddenPlaceResponseItemDto.ObscurityScore.
            // PopularityNorm is inverted here (1 - x) so every score in the DTO reads "higher = more hidden".
            ObscurityScore = 1 - result.PopularityNorm,
            QualityScore = result.RatingNorm,

            PhotoUrl = photo?.Url,
            PhotoAttribution = photo?.Attribution
        };
    }
    public Task<List<RecommendedPlaceSummaryDto>> GetMyPlacesAsync(int currentUserId)
        => _contribution.GetMyPlacesAsync(currentUserId);

    public Task<RecommendedPlaceDetailsDto> GetPlaceDetailsAsync(int currentUserId, string submissionId)
        => _contribution.GetPlaceDetailsAsync(currentUserId, submissionId);

    public Task<SubmitRecommendedPlaceResponseDto> SubmitPlaceAsync(int currentUserId, SubmitRecommendedPlaceRequestDto request)
        => _contribution.SubmitPlaceAsync(currentUserId, request);

    public Task<SubmitRecommendedPlaceResponseDto> UpdateRecommendationAsync(int currentUserId, string submissionId, SubmitRecommendedPlaceRequestDto request)
        => _contribution.UpdateRecommendationAsync(currentUserId, submissionId, request);

    public Task<string> UploadPlaceImageAsync(int currentUserId, Stream fileStream, string fileName, string contentType)
        => _contribution.UploadPlaceImageAsync(currentUserId, fileStream, fileName, contentType);

    public Task<ToggleVerificationResponseDto> ToggleVerificationAsync(int currentUserId, string submissionId, bool verify)
        => _contribution.ToggleVerificationAsync(currentUserId, submissionId, verify);

    public Task<ReportPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason)
        => _contribution.ReportPlaceAsync(currentUserId, submissionId, reason);

    public Task<PlaceReportStatusResponseDto> GetPlaceReportStatusAsync(int currentUserId, string placeId)
        => _contribution.GetPlaceReportStatusAsync(currentUserId, placeId);

    public Task<SubmitRecommendedPlaceResponseDto> WithdrawRecommendationAsync(int currentUserId, string submissionId)
        => _contribution.WithdrawRecommendationAsync(currentUserId, submissionId);

    public Task<List<RecommendedPlaceSummaryDto>> GetPublishedPlacesAsync()
        => _discoverHiddenPlaceService.GetPublishedPlacesAsync();

    public Task<List<string>> GetPrimaryTypeOptionsAsync()
        => _contribution.GetPrimaryTypeOptionsAsync();

    public Task<HiddenPlaceReviewDto?> GetReviewByIdAsync(long reviewId)
        => _reviewService.GetByIdAsync(reviewId);

    public Task<List<HiddenPlaceReviewDto>> GetReviewsByGooglePlaceIdAsync(string googlePlaceId)
        => _reviewService.GetByGooglePlaceIdAsync(googlePlaceId);

    public Task<List<HiddenPlaceReviewDto>> GetReviewsByRecommendPlaceIdAsync(string recommendPlaceId)
        => _reviewService.GetByRecommendPlaceIdAsync(recommendPlaceId);

    public Task<HiddenPlaceReviewDto?> GetUserReviewForGooglePlaceAsync(int userId, string googlePlaceId)
        => _reviewService.GetUserReviewForGooglePlaceAsync(userId, googlePlaceId);

    public Task<HiddenPlaceReviewDto?> GetUserReviewForRecommendPlaceAsync(int userId, string recommendPlaceId)
        => _reviewService.GetUserReviewForRecommendPlaceAsync(userId, recommendPlaceId);

    public Task<HiddenPlaceReviewDto> CreateReviewAsync(int userId, CreateHiddenPlaceReviewRequestDto request)
        => _reviewService.CreateAsync(userId, request);

    public Task<HiddenPlaceReviewDto> UpdateReviewAsync(int userId, long reviewId, UpdateHiddenPlaceReviewRequestDto request)
        => _reviewService.UpdateAsync(userId, reviewId, request);

    public Task DeleteReviewAsync(int userId, long reviewId)
        => _reviewService.DeleteAsync(userId, reviewId);

    public Task<List<HiddenPlaceReviewPhotoDto>> UploadReviewPhotosAsync(int userId, long reviewId, List<IFormFile> files)
        => _reviewService.UploadPhotosAsync(userId, reviewId, files);

    public Task DeleteReviewPhotoAsync(int userId, long reviewId, long reviewPhotoId)
        => _reviewService.DeletePhotoAsync(userId, reviewId, reviewPhotoId);

    public Task ReportReviewAsync(int userId, long reviewId, string reason)
        => _reviewService.ReportAsync(userId, reviewId, reason);
}