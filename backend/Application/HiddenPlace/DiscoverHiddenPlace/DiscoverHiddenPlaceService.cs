namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

/// <summary>
/// Core "冷门度" (hidden-gem) discovery algorithm.
///
/// Runs in two stages:
///   1) Quality gate  - drop places that are closed, unrated/under-reviewed, or a known chain brand.
///                       These aren't "hidden gems" - they're either untrustworthy data points or
///                       inherently not hidden regardless of how few reviews they have locally.
///   2) Scoring       - rank the survivors by how few people know about them (review count, compared
///                       against similar nearby places rather than a global pool) balanced against
///                       how good they actually are (rating).
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

        var survivors = candidates.Where(place => PassesQualityGate(place, options)).ToList();
        if (survivors.Count == 0)
        {
            return Array.Empty<HiddenPlaceResult>();
        }

        // Fallback comparison pool for local groups that are too small to judge fairly on their own.
        var globalMaxReviewCount = survivors.Max(p => p.UserRatingCount);

        var localGroups = survivors
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

        return results
            .OrderByDescending(r => r.HiddenScore)
            .ToList();
    }

    /// <summary>
    /// Stage-1 check for a single candidate, in isolation from the rest of the batch - unlike scoring
    /// (stage 2), the quality gate only looks at the candidate's own fields (rating, review count,
    /// business status, name), so it can be evaluated for one place at a time without needing the full
    /// candidate list. Exposed publicly (rather than kept as a private filter inside Discover) so
    /// callers that persist raw Places API data - see HiddenPlaceService writing to the
    /// hidden_place_cache table - can record whether a place would pass, without having to run the
    /// full Discover pipeline (which also needs the whole local comparison group) just to find out.
    /// </summary>
    public bool PassesQualityGate(PlaceCandidate place, DiscoverHiddenPlaceOptions? options = null)
    {
        options ??= new DiscoverHiddenPlaceOptions();

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
}
