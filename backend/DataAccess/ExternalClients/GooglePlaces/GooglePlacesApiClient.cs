using System.Net.Http.Json;
using System.Text.Json;
using ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;
using ExploreMy.Api.Configuration;
using Microsoft.Extensions.Options;

namespace ExploreMy.Api.DataAccess.ExternalClients.GooglePlaces;

/// <summary>
/// Talks to Google Places API (New). Registered as a typed HttpClient in Program.cs with
/// BaseAddress = https://places.googleapis.com, so this class only ever deals with relative paths.
///
/// This is the ONLY place in the app that knows about Google's request/response JSON shape -
/// everything downstream (the discovery algorithm, the DB, the API to the Flutter app) works
/// with the app's own PlaceCandidate model instead.
/// </summary>
public class GooglePlacesApiClient : IPlacesApiClient
{
    // Only ask Google for the fields the app actually uses - keeps responses small and,
    // for Places API (New), keeps you on the cheaper SKU tier (fewer billed fields).
    private const string FieldMask =
        "places.id,places.displayName,places.primaryType,places.types," +
        "places.location,places.rating,places.userRatingCount,places.priceLevel,places.businessStatus";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly HttpClient _httpClient;
    private readonly GoogleApiSettings _settings;
    private readonly ILogger<GooglePlacesApiClient> _logger;

    public GooglePlacesApiClient(HttpClient httpClient, IOptions<GoogleApiSettings> settings, ILogger<GooglePlacesApiClient> logger)
    {
        _httpClient = httpClient;
        _settings = settings.Value;
        _logger = logger;
    }

    public async Task<IReadOnlyList<PlaceCandidate>> SearchNearbyAsync(
        double latitude,
        double longitude,
        int radiusMeters,
        IReadOnlyList<string> includedTypes,
        int maxResultCount = 20,
        CancellationToken cancellationToken = default)
    {
        var requestBody = new SearchNearbyRequestDto
        {
            IncludedTypes = includedTypes.ToList(),
            MaxResultCount = Math.Clamp(maxResultCount, 1, 20),
            LocationRestriction = new LocationRestrictionDto
            {
                Circle = new CircleDto
                {
                    Center = new LatLngDto { Latitude = latitude, Longitude = longitude },
                    Radius = Math.Clamp(radiusMeters, 1, 50_000)
                }
            }
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, "/v1/places:searchNearby")
        {
            Content = JsonContent.Create(requestBody)
        };
        request.Headers.Add("X-Goog-Api-Key", _settings.ApiKey);
        request.Headers.Add("X-Goog-FieldMask", FieldMask);

        using var response = await _httpClient.SendAsync(request, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogError(
                "Google Places searchNearby failed with {StatusCode} for ({Lat}, {Lng}): {Body}",
                response.StatusCode, latitude, longitude, body);
            throw new InvalidOperationException("Failed to fetch nearby places from Google Places API.");
        }

        var payload = await response.Content.ReadFromJsonAsync<SearchNearbyResponseDto>(JsonOptions, cancellationToken)
            ?? new SearchNearbyResponseDto();

        return payload.Places
            .Select(MapToPlaceCandidate)
            .Where(candidate => candidate is not null)
            .Select(candidate => candidate!)
            .ToList();
    }

    /// <summary>Returns null for entries missing data essential to the algorithm (id/name/location) so callers can skip them.</summary>
    private PlaceCandidate? MapToPlaceCandidate(GooglePlaceDto dto)
    {
        if (dto.Id is null || dto.DisplayName?.Text is null || dto.Location is null)
        {
            _logger.LogWarning("Skipping a Places API result missing id/name/location: {Raw}", dto.Id ?? "(no id)");
            return null;
        }

        var primaryType = dto.PrimaryType ?? dto.Types?.FirstOrDefault() ?? "unknown";

        return new PlaceCandidate
        {
            PlaceId = dto.Id,
            Name = dto.DisplayName.Text,
            PrimaryType = primaryType,
            Latitude = dto.Location.Latitude,
            Longitude = dto.Location.Longitude,
            Rating = dto.Rating,
            UserRatingCount = dto.UserRatingCount ?? 0,
            PriceLevel = GooglePriceLevelMapper.ToNumericLevel(dto.PriceLevel),
            BusinessStatus = dto.BusinessStatus ?? "OPERATIONAL"
        };
    }
}

internal static class GooglePriceLevelMapper
{
    /// <summary>Maps Places API (New) price level enum strings to the 0-4 scale PlaceCandidate uses.</summary>
    public static int? ToNumericLevel(string? priceLevel) => priceLevel switch
    {
        "PRICE_LEVEL_FREE" => 0,
        "PRICE_LEVEL_INEXPENSIVE" => 1,
        "PRICE_LEVEL_MODERATE" => 2,
        "PRICE_LEVEL_EXPENSIVE" => 3,
        "PRICE_LEVEL_VERY_EXPENSIVE" => 4,
        _ => null
    };
}
