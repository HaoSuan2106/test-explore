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

    /// <summary>Average rating 0.0-5.0. Null when Google has no rating yet.</summary>
    public double? Rating { get; init; }

    /// <summary>Total number of user ratings/reviews. This is the main "popularity" proxy signal.</summary>
    public int UserRatingCount { get; init; }

    /// <summary>0 (free) - 4 (very expensive). Null when unknown. Not used in scoring yet, kept for future filters.</summary>
    public int? PriceLevel { get; init; }

    /// <summary>e.g. "OPERATIONAL", "CLOSED_TEMPORARILY", "CLOSED_PERMANENTLY".</summary>
    public string BusinessStatus { get; init; } = "OPERATIONAL";

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
}
