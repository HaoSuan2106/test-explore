using System.Text.Json;
using System.Text.Json.Serialization;

namespace ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;

// Wire-format DTOs for the Places API (New) "searchNearby" endpoint.
// https://developers.google.com/maps/documentation/places/web-service/nearby-search
//
// These intentionally mirror Google's JSON shape 1:1 (nothing but [de]serialization here) so mapping
// into the app's own PlaceCandidate model happens in exactly one place: GooglePlacesApiClient.

public class SearchNearbyRequestDto
{
    [JsonPropertyName("includedTypes")]
    public required List<string> IncludedTypes { get; init; }

    [JsonPropertyName("maxResultCount")]
    public int MaxResultCount { get; init; } = 20;

    /// <summary>"POPULARITY" or "DISTANCE". Omitted from the JSON entirely when null, in which case
    /// Google applies its own default of POPULARITY. What this app sends, and why, is decided in
    /// GooglePlacesApiClient - this DTO only carries the value.</summary>
    [JsonPropertyName("rankPreference")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? RankPreference { get; init; }

    [JsonPropertyName("locationRestriction")]
    public required LocationRestrictionDto LocationRestriction { get; init; }
}

public class LocationRestrictionDto
{
    [JsonPropertyName("circle")]
    public required CircleDto Circle { get; init; }
}

public class CircleDto
{
    [JsonPropertyName("center")]
    public required LatLngDto Center { get; init; }

    [JsonPropertyName("radius")]
    public required double Radius { get; init; }
}

public class LatLngDto
{
    [JsonPropertyName("latitude")]
    public double Latitude { get; init; }

    [JsonPropertyName("longitude")]
    public double Longitude { get; init; }
}

public class SearchNearbyResponseDto
{
    [JsonPropertyName("places")]
    public List<GooglePlaceDto> Places { get; init; } = new();
}

public class GooglePlaceDto
{
    [JsonPropertyName("id")]
    public string? Id { get; init; }

    [JsonPropertyName("displayName")]
    public LocalizedTextDto? DisplayName { get; init; }

    [JsonPropertyName("primaryType")]
    public string? PrimaryType { get; init; }

    /// <summary>Fallback for when Google doesn't set primaryType but does set the broader types list.</summary>
    [JsonPropertyName("types")]
    public List<string>? Types { get; init; }

    [JsonPropertyName("location")]
    public LatLngDto? Location { get; init; }

    [JsonPropertyName("rating")]
    public double? Rating { get; init; }

    [JsonPropertyName("userRatingCount")]
    public int? UserRatingCount { get; init; }

    /// <summary>Enum string, e.g. "PRICE_LEVEL_MODERATE". See GooglePriceLevelMapper for the numeric mapping.</summary>
    [JsonPropertyName("priceLevel")]
    public string? PriceLevel { get; init; }

    [JsonPropertyName("businessStatus")]
    public string? BusinessStatus { get; init; }

    [JsonPropertyName("formattedAddress")]
    public string? FormattedAddress { get; init; }

    [JsonPropertyName("googleMapsUri")]
    public string? GoogleMapsUri { get; init; }

    [JsonPropertyName("websiteUri")]
    public string? WebsiteUri { get; init; }

    [JsonPropertyName("nationalPhoneNumber")]
    public string? NationalPhoneNumber { get; init; }

    /// <summary>
    /// Captured as raw JSON instead of a modelled type. A photo entry is a small object (resource name,
    /// dimensions, authorAttributions) whose only consumer is the client, and the attributions have to be
    /// displayed alongside the image, so passing the array through untouched is both less code and less
    /// likely to quietly drop something Google's terms require. Same reasoning for RegularOpeningHours.
    /// </summary>
    [JsonPropertyName("photos")]
    public JsonElement? Photos { get; init; }

    /// <summary>Standard weekly schedule: `weekdayDescriptions` for display, `periods` for computing
    /// "open now" on the client. Raw JSON for the same reason as Photos.</summary>
    [JsonPropertyName("regularOpeningHours")]
    public JsonElement? RegularOpeningHours { get; init; }

    // ---- Added on top of the original mask. All Pro tier or lower, so free given the mask is already
    // Enterprise - see the FieldMask comment in GooglePlacesApiClient. ----

    /// <summary>Structured postal address components (street, locality, admin areas, postal code, ...),
    /// each with a long name, short name, the applicable component types and a language code. Raw JSON -
    /// same reasoning as Photos: the client is the only consumer and the shape is Google's to define.</summary>
    [JsonPropertyName("addressComponents")]
    public JsonElement? AddressComponents { get; init; }

    /// <summary>The rectangle (low/high lat-lng) that fits the place - used to size and centre a map.
    /// Raw JSON, same reasoning as Photos.</summary>
    [JsonPropertyName("viewport")]
    public JsonElement? Viewport { get; init; }

    /// <summary>Ready-made deep links (directions, place page, write-a-review, reviews, photos), so the
    /// client doesn't have to build them from googleMapsUri. Raw JSON, same reasoning as Photos.</summary>
    [JsonPropertyName("googleMapsLinks")]
    public JsonElement? GoogleMapsLinks { get; init; }

    /// <summary>Wheelchair accessibility flags for parking, entrance, restroom and seating. Raw JSON,
    /// same reasoning as Photos.</summary>
    [JsonPropertyName("accessibilityOptions")]
    public JsonElement? AccessibilityOptions { get; init; }

    /// <summary>Places this one sits inside (e.g. the mall or building housing it) - useful for locating
    /// a place described as "inside X". Raw JSON, same reasoning as Photos.</summary>
    [JsonPropertyName("containingPlaces")]
    public JsonElement? ContainingPlaces { get; init; }

    /// <summary>True when the business has no storefront customers visit (delivery-only, mobile,
    /// home-based, ...). The app's premise is places people travel to, so this is a quality-gate signal,
    /// not presentation detail.</summary>
    [JsonPropertyName("pureServiceAreaBusiness")]
    public bool? PureServiceAreaBusiness { get; init; }

    /// <summary>The date the place opened for business, when Google has it. Distinguishes "new, so few
    /// reviews yet" from "been open a while and still obscure" - the latter is the more interesting kind
    /// of hidden gem. See GooglePlacesApiClient.ToDateOnly for how the {year, month, day} shape here is
    /// turned into a DateOnly.</summary>
    [JsonPropertyName("openingDate")]
    public GoogleDateDto? OpeningDate { get; init; }

    /// <summary>Localized, human-readable type label (e.g. "Cafe" vs. the raw primaryType "cafe"), ready
    /// to show in the UI without a client-side type-to-label table.</summary>
    [JsonPropertyName("primaryTypeDisplayName")]
    public LocalizedTextDto? PrimaryTypeDisplayName { get; init; }

    /// <summary>A shorter form of formattedAddress, better suited to list/card layouts.</summary>
    [JsonPropertyName("shortFormattedAddress")]
    public string? ShortFormattedAddress { get; init; }
}

/// <summary>Wire shape of Google's google.type.Date: a possibly-partial calendar date (year/month/day can
/// each be 0 when Google doesn't know that part). See GooglePlacesApiClient.ToDateOnly.</summary>
public class GoogleDateDto
{
    [JsonPropertyName("year")]
    public int? Year { get; init; }

    [JsonPropertyName("month")]
    public int? Month { get; init; }

    [JsonPropertyName("day")]
    public int? Day { get; init; }
}

public class LocalizedTextDto
{
    [JsonPropertyName("text")]
    public string? Text { get; init; }

    [JsonPropertyName("languageCode")]
    public string? LanguageCode { get; init; }
}
