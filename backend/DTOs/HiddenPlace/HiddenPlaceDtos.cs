using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using System.Text.Json.Serialization;
using ExploreMy.Api.Common.Helpers;

namespace ExploreMy.Api.DTOs.HiddenPlace;

/// <summary>
/// Serializes a stored Malaysia wall-clock DATETIME(6) value as ISO-8601 with an
/// explicit +08:00 offset (e.g. 2026-08-30T21:16:00.123456+08:00) so the Flutter
/// client can parse it unambiguously and render the correct local instant.
///
/// Contract: <c>place_submissions.created_at/updated_at</c> hold MALAYSIA WALL-CLOCK
/// time. EF reads DATETIME(6) back as <c>DateTimeKind.Unspecified</c> whose wall-clock
/// IS Malaysia time, so we attach the explicit Asia/Kuala_Lumpur offset (from
/// <see cref="MalaysiaTime"/>) and let the "K" format specifier emit "+08:00". No +8
/// arithmetic and no reliance on the server OS timezone — the offset comes from the
/// resolved Malaysia <see cref="TimeZoneInfo"/>.
/// </summary>
internal sealed class MalaysiaLocalDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        => reader.GetDateTime();

    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
    {
        // Values may arrive as:
        //  - Unspecified (DATETIME(6) read-back): wall-clock IS Malaysia time → attach offset as-is;
        //  - Utc: an actual UTC instant → convert to Malaysia wall-clock first;
        //  - Local: host-local wall-clock → convert to Malaysia wall-clock first.
        var malaysiaWallClock = value.Kind switch
        {
            DateTimeKind.Utc => MalaysiaTime.FromUtc(value),
            DateTimeKind.Local => TimeZoneInfo.ConvertTime(value, MalaysiaTime.Zone),
            _ => value,
        };

        var offset = new DateTimeOffset(
            DateTime.SpecifyKind(malaysiaWallClock, DateTimeKind.Unspecified),
            MalaysiaTime.Zone.GetUtcOffset(malaysiaWallClock));

        writer.WriteStringValue(
            offset.ToString("yyyy-MM-ddTHH:mm:ss.FFFFFFFK", System.Globalization.CultureInfo.InvariantCulture));
    }
}

public class DiscoverHiddenPlaceRequestDto
{
    [Required, Range(-90, 90)]
    public double Latitude { get; set; }

    [Required, Range(-180, 180)]
    public double Longitude { get; set; }

    // Two search radii are offered to the user: 2.5km or 5km. Anything else - including values
    // technically "in between" that [Range] alone would have allowed - is rejected. Keeping this a
    // closed set (rather than a free-form range) means the grid's cache buckets only ever need to serve
    // two radii, so cache hits stay high instead of getting diluted by arbitrary in-between values. Both
    // are covered by the same fixed grid without changing cell size - only the number of rings scanned
    // varies per request (see SearchGridPlanner.BuildBuckets).
    //
    // Keep this list in step with _radiusOptionsMeters in the Flutter screen
    // (hidden_place_discovery_ui.dart); a value offered there but missing here fails validation.
    [AllowedValues(2_500, 5_000)]
    public int RadiusMeters { get; set; } = 5_000;

    /// <summary>
    /// Google Places type strings, e.g. "restaurant", "cafe", "tourist_attraction". Omit to use the
    /// app's default mix (attractions + food). See:
    /// https://developers.google.com/maps/documentation/places/web-service/place-types
    /// </summary>
    public List<string>? Types { get; set; }

    [Range(1, 20)]
    public int MaxResultCount { get; set; } = 20;
}

/// <summary>Values for <see cref="HiddenPlaceResponseItemDto.Source"/>.</summary>
public static class HiddenPlaceSource
{
    public const string Google = "GOOGLE";
    public const string Community = "COMMUNITY";
}

public class HiddenPlaceResponseItemDto
{
    public string PlaceId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string PrimaryType { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double? Rating { get; set; }
    public int UserRatingCount { get; set; }
    public int? PriceLevel { get; set; }

    public string? FormattedAddress { get; set; }
    public string? GoogleMapsUri { get; set; }
    public string? WebsiteUri { get; set; }
    public string? NationalPhoneNumber { get; set; }

    /// <summary>
    /// Google's `photos` array as raw JSON, passed straight through from the cache. Each entry holds a
    /// photo resource name and the authorAttributions the client must display with the image. The name is
    /// only a reference - the client still has to call Place Photos for the bytes, and that call is billed
    /// separately, so only fetch images actually shown on screen.
    /// </summary>
    public string? PhotosJson { get; set; }

    /// <summary>
    /// Google's `regularOpeningHours` object as raw JSON: `weekdayDescriptions` to display, `periods` to
    /// work out "open now" on the client. This is the standard weekly pattern, so public holidays and
    /// one-off changes are not reflected - query currentOpeningHours live if that matters.
    /// </summary>
    public string? RegularOpeningHoursJson { get; set; }

    /// <summary>Google's `addressComponents` array as raw JSON: structured address parts (street,
    /// locality, admin areas, postal code, ...), each with long/short names and component types.</summary>
    public string? AddressComponentsJson { get; set; }

    /// <summary>Google's `viewport` object as raw JSON: the low/high lat-lng rectangle that fits the
    /// place, for sizing and centring a map.</summary>
    public string? ViewportJson { get; set; }

    /// <summary>Google's `googleMapsLinks` object as raw JSON: ready-made deep links (directions, place
    /// page, write-a-review, reviews, photos).</summary>
    public string? GoogleMapsLinksJson { get; set; }

    /// <summary>Google's `accessibilityOptions` object as raw JSON: wheelchair accessibility flags for
    /// parking, entrance, restroom and seating.</summary>
    public string? AccessibilityOptionsJson { get; set; }

    /// <summary>Google's `containingPlaces` array as raw JSON: places this one sits inside (e.g. a
    /// mall).</summary>
    public string? ContainingPlacesJson { get; set; }

    /// <summary>True when the business has no storefront customers visit (delivery-only, mobile,
    /// home-based, ...).</summary>
    public bool? PureServiceAreaBusiness { get; set; }

    /// <summary>The date the place opened for business, when Google has it and it is a complete date.</summary>
    public DateOnly? OpeningDate { get; set; }

    /// <summary>Localized, human-readable type label (e.g. "Cafe"), distinct from the raw machine-readable
    /// PrimaryType ("cafe").</summary>
    public string? PrimaryTypeDisplayName { get; set; }

    /// <summary>A shorter form of FormattedAddress, better suited to list/card layouts.</summary>
    public string? ShortFormattedAddress { get; set; }

    /// <summary>0.0-1.0, higher = more "hidden gem". The response list is already sorted by this, descending.</summary>
    public double HiddenScore { get; set; }

    /// <summary>
    /// The obscurity half of <see cref="HiddenScore"/>, on its own: 0.0-1.0, higher = fewer people have
    /// reviewed this place compared with similar places nearby (same primary type, same map cell).
    ///
    /// Sent alongside the blended score because the blend is ambiguous by construction - an obscure but
    /// averagely-rated place and a well-known but excellent one land on the same HiddenScore, so the score
    /// alone cannot tell the user which kind of place they are looking at. Measured on a real KL search,
    /// a 25-review museum and a 1663-review temple both scored 0.411.
    ///
    /// Note this is the INVERSE of the internal popularityNorm, so that - like every other score in this
    /// DTO - higher means "more hidden". The client should not have to remember which way round it is.
    /// </summary>
    public double ObscurityScore { get; set; }

    /// <summary>
    /// The quality half of <see cref="HiddenScore"/>, on its own: 0.0-1.0, the place's rating rescaled so
    /// that the algorithm's minimum acceptable rating maps to 0 and 5.0 maps to 1. A place rated exactly at
    /// the minimum scores 0 here, not 0.76 - the absolute rating is already in <see cref="Rating"/>, and
    /// what this field adds is "how far above the bar", which is what actually moves HiddenScore.
    /// </summary>
    public double QualityScore { get; set; }

    /// <summary>
    /// Public URL of this place's photo in our own Supabase bucket, or null when the place has no
    /// picture (common for genuinely obscure places, which is most of what this endpoint returns).
    ///
    /// Deliberately our URL and not Google's: a Place Photos URI is billed per fetch and expires, so
    /// handing one to the app would charge us again on every render. See PlacePhoto.
    /// </summary>
    public string? PhotoUrl { get; set; }

    /// <summary>
    /// Who took the photo. Must be shown wherever the image is - Google's terms require the
    /// attribution to travel with the picture, and because we serve the bytes ourselves, Google is
    /// not there to attach it. Null when Google supplied no attribution, or when there is no photo.
    /// </summary>
    public string? PhotoAttribution { get; set; }

    /// <summary>
    /// Where this place came from: <c>"GOOGLE"</c> for a Places API result, <c>"COMMUNITY"</c> for
    /// one a user submitted and five others verified.
    ///
    /// The client needs this because the two are not interchangeable. A community place has no
    /// Google rating, no review count, and no meaningful <see cref="HiddenScore"/> - those fields
    /// are present but empty, and reading them as if they were real would show every community pick
    /// as a zero-star place. It is also the app's own differentiator, so it is worth showing as such
    /// rather than blending in.
    /// </summary>
    public string Source { get; set; } = HiddenPlaceSource.Google;
}

// Kept to match the original scaffold's file/class naming; the real DTOs above are what's actually used.
// ============================================================
// Recommended Place — request / response
// ============================================================

public class SubmitRecommendedPlaceRequestDto
{
    [Required, MaxLength(150)]
    public string Name { get; set; } = string.Empty;

    [Range(-90, 90)]
    public decimal? Latitude { get; set; }

    [Range(-180, 180)]
    public decimal? Longitude { get; set; }

    [Required, MaxLength(100)]
    public string PrimaryType { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Description { get; set; }

    /// <summary>
    /// Optional price level, 0 (free) through 4 (very expensive). Rejected outside 0-4 server-side;
    /// the UI only offers these five values.
    /// </summary>
    [Range(0, 4)]
    public int? PriceLevel { get; set; }

    /// <summary>
    /// Optional operating status. Server defaults to "OPERATIONAL" when omitted and rejects anything
    /// outside OPERATIONAL / CLOSED_TEMPORARILY. The frontend dropdown alone is not trusted.
    /// </summary>
    public string? BusinessStatus { get; set; }

    /// <summary>
    /// Optional list of up to 3 public photo URLs the user uploaded (references to our Supabase
    /// bucket). Each entry must be an absolute http/https URL; local device paths are rejected.
    /// </summary>
    public List<string>? PhotosJson { get; set; }
}

public class RecommendedPlaceSummaryDto
{
    public string SubmissionId { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public decimal? Latitude { get; init; }
    public decimal? Longitude { get; init; }
    public string PrimaryType { get; init; } = string.Empty;
    public string? Description { get; init; }
    public int? PriceLevel { get; init; }
    public string BusinessStatus { get; init; } = string.Empty;
    public string? PhotosJson { get; init; }
    public string Status { get; init; } = string.Empty;
    public int VerificationCount { get; init; }
    public int ReportCount { get; init; }
    public int RequiredVerifications { get; init; }
    [JsonConverter(typeof(MalaysiaLocalDateTimeConverter))]
    public DateTime CreatedAt { get; init; }
    [JsonConverter(typeof(MalaysiaLocalDateTimeConverter))]
    public DateTime UpdatedAt { get; init; }
}

public class RecommendedPlaceDetailsDto : RecommendedPlaceSummaryDto
{
    public int SubmitterId { get; init; }
    public string SubmitterName { get; init; } = string.Empty;
    public bool IsCurrentUserSubmitter { get; init; }
    public bool IsVerifiedByCurrentUser { get; init; }

    /// <summary>
    /// True when the current user has already reported this place. Place Report is
    /// ONE-TIME per (user, place) — the UI keeps the Report Place action disabled
    /// based on this persisted value, not on same-session UI state.
    /// </summary>
    public bool IsReportedByCurrentUser { get; init; }
}

public class SubmitRecommendedPlaceResponseDto
{
    public string SubmissionId { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}

public class WithdrawRecommendedPlaceResponseDto
{
    public string SubmissionId { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}

// ============================================================
// Verification (community voting)
// ============================================================

public class ToggleVerificationRequestDto
{
    /// <summary>true = verify; false = withdraw a previous verification.</summary>
    [Required]
    public bool Verify { get; set; }
}

public class ToggleVerificationResponseDto
{
    public string SubmissionId { get; init; } = string.Empty;
    public bool IsVerified { get; init; }
    public int VerificationCount { get; init; }
    public string PlaceStatus { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}

// ============================================================
// Place reports — storage: hidden_place_suppression
// One ACTIVE report per (user, place); NOT a toggle. report_count
// is kept internally for the hide threshold but never shown in the UI.
// ============================================================

public class ReportPlaceRequestDto
{
    /// <summary>One of the supported PLACE report reasons (see PlaceReportReasons).</summary>
    [Required, MaxLength(100)]
    public string Reason { get; set; } = string.Empty;
}

public class ReportPlaceResponseDto
{
    public string SubmissionId { get; init; } = string.Empty;

    /// <summary>
    /// Total number of reports against the place (aggregate of one-row-per-user
    /// reports). Kept for the internal hide threshold — the UI must NOT display it.
    /// </summary>
    public int ReportCount { get; init; }
    public string PlaceStatus { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}

public class HiddenPlaceDtos
{
}