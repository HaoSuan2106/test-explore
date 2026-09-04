using ExploreMy.Api.Domain.Entities;

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

    /// <summary>
    /// Places with fewer reviews than this are dropped as too unverified to trust.
    ///
    /// Set to 1, i.e. effectively off - only places with no reviews at all are excluded, since those have
    /// no rating to judge and nothing for HiddenScore to work with.
    ///
    /// Be aware of what this lets in. HiddenScore rewards obscurity AND a high rating, and a place with a
    /// handful of reviews is usually rated 5.0 by one or two people, so those entries take over the top of
    /// the list: at a floor of 5, an entire sampled KL top 10 had 15 reviews or fewer. They are not hidden
    /// gems so much as places nobody has assessed yet. Raise this to 20 if the results start looking like
    /// a list of unrated newcomers.
    /// </summary>
    public int MinUserRatingCount { get; init; } = 1;

    /// <summary>
    /// A relative "this is too well-known" test, expressed as a position rather than a number: within a
    /// primary type, the most-reviewed places above this percentile are dropped. At 0.6 the best-known 40%
    /// of each type would be removed.
    ///
    /// CURRENTLY OFF (1.0 keeps everything, leaving MaxUserRatingCount as the only ceiling). The mechanism
    /// is kept because the problem it addresses is real: the review count that means "famous" differs
    /// enormously by type. In a sampled KL search the 60th percentile was 129 reviews for coffee_shop, 179
    /// for cafe, 282 for restaurant, 421 for tourist_attraction and 1066 for museum - an eight-fold spread
    /// inside one city - so any single number is wrong for most types, and wrong again in the next town.
    ///
    /// It is off because it needs a sample that has not already been filtered by popularity, and the
    /// current intake does not provide one: Places API searchNearby ranks by POPULARITY, so each type's
    /// queue arrives already made of that type's best-known places, and "the least famous 60% of the most
    /// famous 20" is still famous. Measured effect - cafe's computed ceiling rose from 179 to 1781 once
    /// buckets were refetched under POPULARITY.
    ///
    /// Set it back to 0.6 once the intake gives a fairer sample - by narrowing HiddenPlaceService.
    /// DefaultTypes so each request's top-20 reaches deeper into the tail, or by ranking by DISTANCE.
    /// </summary>
    public double MaxUserRatingPercentile { get; init; } = 1.0;

    /// <summary>
    /// A type needs at least this many places in the search before its own percentile is trusted. Below it,
    /// that type falls back to the percentile of the whole result set - a percentile over two or three
    /// places is noise, and in a small group that happens to hold only famous places it would compute an
    /// absurdly high ceiling and let all of them through.
    /// </summary>
    public int MinGroupSizeForPercentileCeiling { get; init; } = 5;

    /// <summary>
    /// Hard ceiling: nothing above this is ever returned, whatever its type's local distribution says.
    ///
    /// With MaxUserRatingPercentile off, this is currently the ONLY thing keeping well-known places out of
    /// the results, so it is doing the whole job on its own. At 2000 that job is loose - a sampled KL
    /// search left 136 results whose median was 578 reviews and of which 39 had over 1000. Lower it (800
    /// leaves 87 of those 136, 500 leaves 52) if famous places are still showing up; the trade-off is that a
    /// single number cannot tell a well-known cafe from a quiet museum, which is what the percentile above
    /// exists to fix once the intake can support it.
    ///
    /// Note the ceilings are applied to what gets RETURNED, not to what gets scored - see referencePool in
    /// DiscoverHiddenPlaceService.Discover. Excluding popular places before scoring would shrink the divisor
    /// in NormalizeReviewCount and deflate every remaining HiddenScore, which is how an earlier version made
    /// this setting and MinHiddenScore multiply together instead of acting independently.
    /// </summary>
    public int MaxUserRatingCount { get; init; } = 2000;

    /// <summary>Only candidates with one of these statuses are eligible. Closed places should never surface.</summary>
    public HashSet<string> AllowedBusinessStatuses { get; init; } =
        new(StringComparer.OrdinalIgnoreCase) { BusinessStatus.Operational };

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

    // ---- Stage 3: the cut. Applied to scored results, immediately before they are returned. ----

    /// <summary>
    /// Results scoring below this are dropped instead of merely being ranked last. Off (0) by default:
    /// MaxUserRatingCount now does the job this was meant for, and does it more precisely.
    ///
    /// The attempt is worth recording. Set to 0.45 on its own it cut 123 of 231 sampled results, and the
    /// cut was indiscriminate - HiddenScore blends obscurity with rating, so around 0.35-0.45 a 25-review
    /// museum (MoSAIC, 0.411) and a 1663-review temple (Buddhist Maha Vihara, 0.411) are indistinguishable.
    /// The rating term is what blurs them: MinRating compresses ratings into a 3.8-5.0 band, and a perfect
    /// 5.0 almost only occurs on places with single-digit review counts, so the term ends up rewarding
    /// "barely reviewed" a second time while a genuinely good 4.4 place is penalised at both ends.
    ///
    /// Raise it above 0 only to trim the bottom of an already review-capped list, never as the primary
    /// definition of hidden. If you do, mind the interaction described on MaxUserRatingCount.
    /// </summary>
    public double MinHiddenScore { get; init; } = 0;
}
