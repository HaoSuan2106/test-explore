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
}

public class LocalizedTextDto
{
    [JsonPropertyName("text")]
    public string? Text { get; init; }

    [JsonPropertyName("languageCode")]
    public string? LanguageCode { get; init; }
}
