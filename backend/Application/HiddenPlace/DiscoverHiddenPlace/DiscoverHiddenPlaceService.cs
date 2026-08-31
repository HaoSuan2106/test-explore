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
