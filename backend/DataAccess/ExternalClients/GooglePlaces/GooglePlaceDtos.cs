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
}

public class LocalizedTextDto
{
    [JsonPropertyName("text")]
    public string? Text { get; init; }

    [JsonPropertyName("languageCode")]
    public string? LanguageCode { get; init; }
}
