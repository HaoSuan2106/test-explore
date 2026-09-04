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
    public string BusinessStatus { get; set; } = global::ExploreMy.Api.Domain.Entities.BusinessStatus.Operational;

    // ---- Presentation detail. Cached purely so a place can be displayed without a second round-trip to
    // Google; none of it feeds the discovery algorithm. See PlaceCandidate for the per-field notes. ----

    public string? FormattedAddress { get; set; }
    public string? GoogleMapsUri { get; set; }
    public string? WebsiteUri { get; set; }
    public string? NationalPhoneNumber { get; set; }

    /// <summary>Google's `photos` array, stored verbatim in a MySQL json column. Photo resource names plus
    /// the authorAttributions that must be shown with the image. Fetching an actual image is a separate,
    /// separately billed Place Photos request - this only holds the references.</summary>
    public string? PhotosJson { get; set; }

    /// <summary>Google's `regularOpeningHours` object, stored verbatim in a MySQL json column: the standard
    /// weekly pattern, which changes rarely enough to survive the cache TTL. `currentOpeningHours` is not
    /// stored - it is computed per request and would go stale within a day.</summary>
    public string? RegularOpeningHoursJson { get; set; }

    // ---- Added on top of the original field set. All Pro tier or lower - free, since the mask is
    // already Enterprise. See the FieldMask comment on GooglePlacesApiClient. ----

    /// <summary>Google's `addressComponents` array, stored verbatim in a MySQL json column: structured
    /// address parts (street, locality, admin areas, postal code, ...), each with long/short names and
    /// component types. Presentation/filtering detail; not used by the scoring algorithm.</summary>
    public string? AddressComponentsJson { get; set; }

    /// <summary>Google's `viewport` object, stored verbatim in a MySQL json column: the low/high lat-lng
    /// rectangle that fits the place, for sizing and centring a map. Presentation detail only.</summary>
    public string? ViewportJson { get; set; }

    /// <summary>Google's `googleMapsLinks` object, stored verbatim in a MySQL json column: ready-made deep
    /// links (directions, place page, write-a-review, reviews, photos). Presentation detail only.</summary>
    public string? GoogleMapsLinksJson { get; set; }

    /// <summary>Google's `accessibilityOptions` object, stored verbatim in a MySQL json column: wheelchair
    /// accessibility flags for parking, entrance, restroom and seating. Presentation detail only.</summary>
    public string? AccessibilityOptionsJson { get; set; }

    /// <summary>Google's `containingPlaces` array, stored verbatim in a MySQL json column: places this one
    /// sits inside (e.g. a mall). Presentation detail only.</summary>
    public string? ContainingPlacesJson { get; set; }

    /// <summary>True when the business has no storefront customers visit (delivery-only, mobile,
    /// home-based, ...). Data only for now - NOT yet checked by DiscoverHiddenPlaceService.PassesQualityGate.
    /// The app's premise is places people travel to, so wiring this into the quality gate (reject when
    /// true) is the natural next step, deliberately left for a separate change.</summary>
    public bool? PureServiceAreaBusiness { get; set; }

    /// <summary>The date the place opened for business, when Google has it and it is a complete
    /// year/month/day. Not yet used by scoring; kept for a future "new vs. long-open but still obscure"
    /// refinement.</summary>
    public DateOnly? OpeningDate { get; set; }

    /// <summary>Localized, human-readable type label (e.g. "Cafe"), distinct from the raw machine-readable
    /// PrimaryType ("cafe"). Presentation detail only.</summary>
    public string? PrimaryTypeDisplayName { get; set; }

    /// <summary>A shorter form of FormattedAddress, better suited to list/card layouts. Presentation
    /// detail only.</summary>
    public string? ShortFormattedAddress { get; set; }

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
