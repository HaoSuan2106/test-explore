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
    // Only ask Google for the fields the app actually uses.
    //
    // Places API (New) bills per call by TIER, and the tier is set by the most expensive field in this
    // mask - not by how many fields are listed. rating, userRatingCount, priceLevel, websiteUri,
    // nationalPhoneNumber and regularOpeningHours are all Enterprise; everything else here is Pro or
    // below. So this whole mask costs exactly what rating alone already cost, and adding any further
    // Pro/Enterprise field is free.
    //
    // addressComponents, viewport, googleMapsLinks, accessibilityOptions, containingPlaces,
    // pureServiceAreaBusiness, openingDate, primaryTypeDisplayName and shortFormattedAddress were added
    // on that basis - all Pro tier, so none of them raise the price of a call that was already Enterprise.
    //
    // What is NOT free, and is deliberately absent: editorialSummary, reviews, generativeSummary and the
    // amenity flags (servesBreakfast, allowsDogs, outdoorSeating, ...) sit in Enterprise + Atmosphere.
    // Adding any one of them raises the price of EVERY call, including calls that never read it.
    //
    // Also absent by design: currentOpeningHours. It is computed for the seven days around the request,
    // so caching it for 30 days would serve confidently wrong answers. regularOpeningHours is the
    // cacheable half - see PlaceCandidate.RegularOpeningHoursJson.
    private const string FieldMask =
        "places.id,places.displayName,places.primaryType,places.types," +
        "places.location,places.rating,places.userRatingCount,places.priceLevel,places.businessStatus," +
        "places.formattedAddress,places.googleMapsUri,places.websiteUri,places.nationalPhoneNumber," +
        "places.photos,places.regularOpeningHours," +
        // Everything below is Pro tier or lower - free additions, since rating/userRatingCount/priceLevel/
        // websiteUri/nationalPhoneNumber/regularOpeningHours above already put the whole call in Enterprise.
        "places.addressComponents,places.viewport,places.googleMapsLinks,places.accessibilityOptions," +
        "places.containingPlaces,places.pureServiceAreaBusiness,places.openingDate," +
        "places.primaryTypeDisplayName,places.shortFormattedAddress";

    // How Google decides WHICH places to return when a cell holds more matches than the 20-result cap
    // allows. searchNearby offers only these two orderings; there is no "rank by review count" and no
    // server-side review-count filter, so this single choice determines what can ever enter
    // hidden_place_cache, and nothing downstream can recover a place it excludes.
    //
    // POPULARITY (Google's default) returns each cell's 20 best-known places. Every one of them has real
    // reviews, so no part of the budget is wasted - but a search for hidden gems then never sees anything
    // else. In a cell holding 50 cafes, the 30 obscure ones are simply never fetched, and the scoring
    // downstream is left picking the least famous of the most famous. Measured on a real KL search the
    // results had a median of 578 reviews, with 39 of 136 above 1000.
    //
    // DISTANCE returns the 20 places nearest the cell centre instead. No popularity bias, so the sample
    // reaching the quality gate and HiddenScore is a fair one and genuinely obscure places can surface.
    // This is the ranking the app's premise requires.
    //
    // Its cost is real and worth knowing: an unbiased sample of a dense area contains a lot of barely
    // reviewed entries. Roughly half of what DISTANCE returned in the same KL search had fewer than five
    // reviews - not hidden gems, just places nobody has assessed - so a meaningful share of each call's 20
    // slots buys nothing. DiscoverHiddenPlaceOptions.MinUserRatingCount is the lever for how much of that
    // to tolerate.
    //
    // Two knock-on effects if this is changed: every already-cached row was fetched under the other
    // ranking, so TRUNCATE hidden_place_cache afterwards; and DISTANCE results cluster near each cell
    // centre rather than spreading across it, so if coverage gaps appear the fix is a smaller
    // SearchGridPlanner.CellHalfWidthMeters, not switching back.
    private const string RankPreference = "DISTANCE";

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
            RankPreference = RankPreference,
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

    public async Task<string?> GetPhotoUriAsync(
        string photoReference,
        int maxWidthPx,
        CancellationToken cancellationToken = default)
    {
        // skipHttpRedirect makes Google answer with a small JSON body naming the image URI, instead of
        // a 302 straight to its CDN. That is a security choice, not a style one: HttpClient follows
        // redirects by default and re-sends custom headers to the new host, so the plain form would
        // hand our API key to googleusercontent.com on every photo. This way the key never leaves
        // googleapis.com, and the download itself is done by a separate client with no credentials.
        var requestUri = $"/v1/{photoReference}/media?maxWidthPx={maxWidthPx}&skipHttpRedirect=true";

        using var request = new HttpRequestMessage(HttpMethod.Get, requestUri);
        request.Headers.Add("X-Goog-Api-Key", _settings.ApiKey);

        using var response = await _httpClient.SendAsync(request, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogWarning(
                "Google Place Photos returned {StatusCode} for {PhotoReference}: {Body}",
                response.StatusCode, photoReference, body);
            return null;
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);

        return document.RootElement.TryGetProperty("photoUri", out var photoUri)
               && photoUri.ValueKind == JsonValueKind.String
            ? photoUri.GetString()
            : null;
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
            BusinessStatus = dto.BusinessStatus ?? "OPERATIONAL",
            FormattedAddress = dto.FormattedAddress,
            GoogleMapsUri = dto.GoogleMapsUri,
            WebsiteUri = dto.WebsiteUri,
            NationalPhoneNumber = dto.NationalPhoneNumber,
            PhotosJson = RawJsonOrNull(dto.Photos),
            RegularOpeningHoursJson = RawJsonOrNull(dto.RegularOpeningHours),
            AddressComponentsJson = RawJsonOrNull(dto.AddressComponents),
            ViewportJson = RawJsonOrNull(dto.Viewport),
            GoogleMapsLinksJson = RawJsonOrNull(dto.GoogleMapsLinks),
            AccessibilityOptionsJson = RawJsonOrNull(dto.AccessibilityOptions),
            ContainingPlacesJson = RawJsonOrNull(dto.ContainingPlaces),
            PureServiceAreaBusiness = dto.PureServiceAreaBusiness,
            OpeningDate = ToDateOnly(dto.OpeningDate),
            PrimaryTypeDisplayName = dto.PrimaryTypeDisplayName?.Text,
            ShortFormattedAddress = dto.ShortFormattedAddress
        };
    }

    /// <summary>
    /// Converts Google's {year, month, day} openingDate object to a DateOnly. Null whenever any part is
    /// missing or zero - Google's google.type.Date allows a year-only or month/day-only date (0 in the
    /// unset parts), and DateOnly cannot represent a partial date, so a partial value is dropped rather
    /// than guessed at.
    /// </summary>
    private static DateOnly? ToDateOnly(GoogleDateDto? date)
    {
        if (date is not { Year: > 0, Month: > 0, Day: > 0 })
        {
            return null;
        }

        try
        {
            return new DateOnly(date.Year.Value, date.Month.Value, date.Day.Value);
        }
        catch (ArgumentOutOfRangeException)
        {
            return null;
        }
    }

    /// <summary>
    /// Serialises a captured JSON value back to its original text, or null when Google omitted the field.
    ///
    /// Null rather than "null" or "" on purpose: these land in MySQL `json` columns, which accept SQL NULL
    /// but reject an empty string, and a literal "null" would force every reader to distinguish
    /// "no photos" from "the JSON value null".
    /// </summary>
    private static string? RawJsonOrNull(JsonElement? element) =>
        element is null || element.Value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null
            ? null
            : element.Value.GetRawText();
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
