using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

/// <summary>
/// Raw place data pulled from the Google Places API (Nearby Search / Place Details),
/// already mapped into the shape the discovery algorithm needs. This class deliberately
/// knows nothing about HTTP or Google's JSON shape — that mapping belongs in the Places API
/// client, not here, so the algorithm below stays easy to unit test.
/// </summary>
public class PlaceCandidate
{
    /// <summary>Google Places "place_id" / "id" — stable key, used later to fetch details/photos.</summary>
    public required string PlaceId { get; init; }

    public required string Name { get; init; }

    /// <summary>e.g. "restaurant", "tourist_attraction", "cafe" — Places API primaryType/first type.</summary>
    public required string PrimaryType { get; init; }

    public double Latitude { get; init; }
    public double Longitude { get; init; }

    /// <summary>Average rating 0.0-5.0, AS GOOGLE HAS IT. Null when Google has no rating yet.
    /// Scoring reads <see cref="EffectiveRating"/> instead; this stays untouched so the app can still
    /// show "what Google says" next to what our own users say.</summary>
    public double? Rating { get; init; }

    /// <summary>Number of user ratings/reviews ON GOOGLE. Scoring reads
    /// <see cref="EffectiveUserRatingCount"/>; see that property for why the two are separate.</summary>
    public int UserRatingCount { get; init; }

    // ---- Our own app's reviews of this same place. Settable rather than init-only because they are
    // attached AFTER the candidate is built: the candidate comes out of Google or the cache, then
    // HiddenPlaceService.AttachAppReviewStatsAsync fills these in from our reviews table in one
    // batched read. Both stay at their defaults (no reviews) for any caller that skips that step, and
    // the Effective* properties below then reduce to the plain Google numbers. ----

    /// <summary>Average rating our own users gave this place, or null when nobody here has reviewed
    /// it. Only ACTIVE reviews count - a review removed by reports must not keep voting.</summary>
    public double? AppRating { get; set; }

    /// <summary>How many ACTIVE reviews our own users wrote about this place. 0 for most places.</summary>
    public int AppReviewCount { get; set; }

    /// <summary>
    /// The rating the algorithm actually scores: Google's and ours pooled, each weighted by how many
    /// people it represents.
    ///
    /// Weighted rather than averaged flat, because the two samples are nowhere near the same size -
    /// giving 3 of our reviews the same say as 800 of Google's would let a handful of our users swing
    /// a place's quality score entirely. As our review count grows, our voice grows with it, which is
    /// the behaviour we want and needs no threshold to switch over.
    /// </summary>
    public double? EffectiveRating
    {
        get
        {
            if (AppReviewCount <= 0 || AppRating is null)
            {
                return Rating;
            }

            if (Rating is null || UserRatingCount <= 0)
            {
                // Nobody on Google has rated it, so ours is the only rating there is. This is also
                // what lets a place Google has no opinion about clear the rating gate at all.
                return AppRating;
            }

            var total = UserRatingCount + AppReviewCount;
            return ((Rating.Value * UserRatingCount) + (AppRating.Value * AppReviewCount)) / total;
        }
    }

    /// <summary>
    /// The "how many people know about this" count the algorithm actually scores: Google's reviewers
    /// plus ours.
    ///
    /// Our reviews count toward popularity, not just quality, because a place our own community has
    /// already written about is, by that much, less of a discovery for the next person. Today this
    /// barely moves anything - a few reviews against Google's hundreds - and that is the point: it
    /// scales in on its own as the app grows, instead of needing to be switched on later.
    /// </summary>
    public int EffectiveUserRatingCount => UserRatingCount + AppReviewCount;

    /// <summary>0 (free) - 4 (very expensive). Null when unknown. Not used in scoring yet, kept for future filters.</summary>
    public int? PriceLevel { get; init; }

    /// <summary>e.g. "OPERATIONAL", "CLOSED_TEMPORARILY", "CLOSED_PERMANENTLY".</summary>
    public string BusinessStatus { get; init; } = global::ExploreMy.Api.Domain.Entities.BusinessStatus.Operational;

    // ---- Presentation detail. None of the following is used by the scoring algorithm; it is carried
    // through so the app can show a place without a second round-trip to Google. ----

    /// <summary>Full human-readable address, e.g. "12, Jalan Sultan, 50000 Kuala Lumpur". Null if absent.</summary>
    public string? FormattedAddress { get; init; }

    /// <summary>Link to this place on Google Maps - the target for a "get directions" button.</summary>
    public string? GoogleMapsUri { get; init; }

    /// <summary>The place's own website, when it has one.</summary>
    public string? WebsiteUri { get; init; }

    /// <summary>Phone number in local format, e.g. "03-1234 5678".</summary>
    public string? NationalPhoneNumber { get; init; }

    /// <summary>
    /// The raw JSON array Google returned for `photos`, kept verbatim rather than modelled in C#.
    ///
    /// Each entry carries a photo resource name plus the authorAttributions that Google's terms require to
    /// be shown alongside the image, so keeping the array whole avoids silently dropping the attribution.
    /// The name is only a reference: fetching the actual image is a separate, separately billed Place
    /// Photos request.
    /// </summary>
    public string? PhotosJson { get; init; }

    /// <summary>
    /// The raw JSON object Google returned for `regularOpeningHours`, kept verbatim.
    ///
    /// Holds both `weekdayDescriptions` (ready to display) and `periods` (structured, so the client can
    /// work out "open now" itself). Regular hours are the standard weekly pattern and change rarely, which
    /// is what makes them safe to cache. `currentOpeningHours` is deliberately NOT requested: it is
    /// computed for the seven days around the request, so a cached copy is wrong within a day.
    /// </summary>
    public string? RegularOpeningHoursJson { get; init; }

    // ---- Added on top of the original field set. All Pro tier or lower - free, since the mask is
    // already Enterprise. See the FieldMask comment in GooglePlacesApiClient. ----

    /// <summary>The raw JSON array Google returned for `addressComponents` - structured address parts
    /// (street, locality, admin areas, postal code, ...), each with long/short names and component
    /// types. Presentation/filtering detail; not used by the scoring algorithm.</summary>
    public string? AddressComponentsJson { get; init; }

    /// <summary>The raw JSON object Google returned for `viewport` - the low/high lat-lng rectangle that
    /// fits the place, for sizing and centring a map. Presentation detail only.</summary>
    public string? ViewportJson { get; init; }

    /// <summary>The raw JSON object Google returned for `googleMapsLinks` - ready-made deep links
    /// (directions, place page, write-a-review, reviews, photos). Presentation detail only.</summary>
    public string? GoogleMapsLinksJson { get; init; }

    /// <summary>The raw JSON object Google returned for `accessibilityOptions` - wheelchair accessibility
    /// flags for parking, entrance, restroom and seating. Presentation detail only.</summary>
    public string? AccessibilityOptionsJson { get; init; }

    /// <summary>The raw JSON array Google returned for `containingPlaces` - places this one sits inside
    /// (e.g. a mall). Presentation detail only.</summary>
    public string? ContainingPlacesJson { get; init; }

    /// <summary>True when the business has no storefront customers visit (delivery-only, mobile,
    /// home-based, ...). Data only for now - NOT yet checked by DiscoverHiddenPlaceService.PassesQualityGate.
    /// The app's premise is places people travel to, so wiring this into the quality gate (reject when
    /// true) is the natural next step, deliberately left for a separate change.</summary>
    public bool? PureServiceAreaBusiness { get; init; }

    /// <summary>The date the place opened for business, when Google has it. Null rather than a partial
    /// date whenever Google's year/month/day isn't fully known - see GooglePlacesApiClient.ToDateOnly.
    /// Not yet used by scoring; kept for a future "new vs. long-open but still obscure" refinement.</summary>
    public DateOnly? OpeningDate { get; init; }

    /// <summary>Localized, human-readable type label (e.g. "Cafe"), distinct from the raw machine-readable
    /// PrimaryType ("cafe"). Presentation detail only.</summary>
    public string? PrimaryTypeDisplayName { get; init; }

    /// <summary>A shorter form of FormattedAddress, better suited to list/card layouts. Presentation
    /// detail only.</summary>
    public string? ShortFormattedAddress { get; init; }
}
