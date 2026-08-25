using System.ComponentModel.DataAnnotations;

namespace ExploreMy.Api.DTOs.HiddenPlace;

public class DiscoverHiddenPlaceRequestDto
{
    [Required, Range(-90, 90)]
    public double Latitude { get; set; }

    [Required, Range(-180, 180)]
    public double Longitude { get; set; }

    // Only two search radii are offered to the user: 5km or 10km. Anything else - including values
    // technically "in between" that [Range] alone would have allowed - is rejected. Keeping this a
    // closed set (rather than a free-form range) means the grid's cache buckets only ever need to serve
    // two radii, so cache hits stay high instead of getting diluted by arbitrary in-between values.
    [AllowedValues(5_000, 10_000)]
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

    /// <summary>0.0-1.0, higher = more "hidden gem". The response list is already sorted by this, descending.</summary>
    public double HiddenScore { get; set; }
}

// Kept to match the original scaffold's file/class naming; the real DTOs above are what's actually used.
public class HiddenPlaceDtos
{
}
