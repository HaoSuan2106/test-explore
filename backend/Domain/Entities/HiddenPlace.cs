namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A cached row from Google Places API, scoped to one "bucket" - a (place type, fixed geographic
/// grid cell) combination. This is a disposable cache table, not a source of truth: its only job
/// is to let repeat searches over the same area/type reuse a recent Google Places API result
/// instead of paying for and waiting on another call every time. See SearchGridPlanner and
/// HiddenPlaceService for how buckets are built and consumed.
/// </summary>
public class HiddenPlace
{
    public int HiddenPlaceCacheId { get; set; }

    /// <summary>e.g. "restaurant:118:5761" - place type + fixed grid cell coordinates. Every row
    /// fetched under the same search bucket shares this key.</summary>
    public string CacheGridKey { get; set; } = string.Empty;

    /// <summary>When this row's bucket was last fetched from Google. All rows in the same bucket
    /// share this timestamp - a bucket is replaced (old rows deleted, new rows inserted) as a whole.</summary>
    public DateTime FetchedAtUtc { get; set; }

    public string PlaceId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string PrimaryType { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double? Rating { get; set; }
    public int UserRatingCount { get; set; }
    public int? PriceLevel { get; set; }
    public string BusinessStatus { get; set; } = "OPERATIONAL";

    /// <summary>
    /// Whether this row passed DiscoverHiddenPlaceService's stage-1 quality gate (business status,
    /// rating, review count, chain-brand name check) at the time it was fetched from Google. This is
    /// the ABSOLUTE part of the algorithm only - it does NOT mean the place is a top-ranked "hidden
    /// gem", since the relative HiddenScore (compared against nearby same-type places) is computed
    /// fresh on every request and never persisted - two different searches can rank the same place
    /// differently depending on what else got pulled into its local comparison group (see
    /// DiscoverHiddenPlaceService.Discover). Use this column to query "places that are at least
    /// plausibly hidden gems" directly from the cache, e.g.:
    ///   SELECT * FROM hidden_place_cache WHERE passed_quality_gate = 1;
    /// </summary>
    public bool PassedQualityGate { get; set; }
}
