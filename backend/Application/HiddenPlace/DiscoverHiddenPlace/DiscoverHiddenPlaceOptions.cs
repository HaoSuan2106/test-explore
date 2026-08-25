namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

/// <summary>
/// Tunable thresholds/weights for the hidden-place discovery algorithm. Defaults below are
/// reasonable starting points for an MVP — revisit them once real Places API data is flowing
/// (e.g. by looking at the actual review-count distribution in your target city).
/// </summary>
public class DiscoverHiddenPlaceOptions
{
    // ---- Stage 1: quality gate. A place must clear all of these before it is even considered. ----

    /// <summary>Places below this rating are "not good enough to recommend", not "hidden gems".</summary>
    public double MinRating { get; init; } = 3.8;

    /// <summary>Places with fewer reviews than this are too unverified to trust (could be fake, brand new, or inactive).</summary>
    public int MinUserRatingCount { get; init; } = 5;

    /// <summary>Only candidates with one of these statuses are eligible. Closed places should never surface.</summary>
    public HashSet<string> AllowedBusinessStatuses { get; init; } =
        new(StringComparer.OrdinalIgnoreCase) { "OPERATIONAL" };

    /// <summary>
    /// Case-insensitive substring match against the place name. A hit means "known chain/franchise" and the
    /// place is excluded outright — a Starbucks with 20 reviews in a small town is still not "hidden".
    /// Extend this list for your target market (Malaysian chains included as a starting point).
    /// </summary>
    public HashSet<string> ChainBrandKeywords { get; init; } = new(StringComparer.OrdinalIgnoreCase)
    {
        "mcdonald", "starbucks", "kfc", "subway", "burger king", "pizza hut",
        "domino", "7-eleven", "familymart", "old town", "secret recipe", "texas chicken"
    };

    // ---- Stage 2: scoring, applied only to candidates that survive stage 1. ----

    /// <summary>Weight given to "few people know about this" (0-1). Higher favors obscurity more.</summary>
    public double PopularityWeight { get; init; } = 0.7;

    /// <summary>Weight given to rating/quality (0-1). PopularityWeight + QualityWeight should sum to 1.</summary>
    public double QualityWeight { get; init; } = 0.3;

    /// <summary>
    /// Places are compared against nearby same-type places rather than a global pool, so a 50-review cafe in a
    /// small town isn't automatically scored the same as a 50-review cafe in a dense city center. Grid cell size
    /// in degrees; ~0.05 degrees is roughly 5 km.
    /// </summary>
    public double LocalGroupGridSizeDegrees { get; init; } = 0.05;

    /// <summary>
    /// A local group smaller than this has too little data for a fair relative comparison, so those candidates
    /// fall back to being compared against the whole input batch instead of just their tiny local group.
    /// </summary>
    public int MinGroupSizeForLocalComparison { get; init; } = 3;
}
