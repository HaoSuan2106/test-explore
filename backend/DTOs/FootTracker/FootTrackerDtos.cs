using System.ComponentModel.DataAnnotations;

namespace ExploreMy.Api.DTOs.FootTracker;

public class FavouritePlaceDto
{
    public int FavouritePlaceId { get; set; }
    public string PlaceId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string PrimaryType { get; set; } = string.Empty;
    public string? Address { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public DateTime? LastVisitAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? PhotoUrl { get; set; }
    public string? PhotoAttribution { get; set; }
}

public class AddFavouritePlaceRequestDto
{
    [Required]
    public string PlaceId { get; set; } = string.Empty;

    [Required]
    public string Name { get; set; } = string.Empty;

    [Required]
    public string PrimaryType { get; set; } = string.Empty;

    public string? Address { get; set; }

    public double Latitude { get; set; }
    public double Longitude { get; set; }
}

public class RemoveFavouritePlacesRequestDto
{
    [Required, MinLength(1)]
    public List<int> FavouritePlaceIds { get; set; } = new();
}

public class RouteRequestDto
{
    [Required]
    public double OriginLatitude { get; set; }

    [Required]
    public double OriginLongitude { get; set; }

    [Required]
    public double DestinationLatitude { get; set; }

    [Required]
    public double DestinationLongitude { get; set; }

    /// One of: "foot-walking" (default), "cycling-regular", "driving-car".
    public string Profile { get; set; } = "foot-walking";
}

public class RoutePointDto
{
    public double Latitude { get; set; }
    public double Longitude { get; set; }
}

public class RouteResponseDto
{
    public List<RoutePointDto> Points { get; set; } = new();
    public double DistanceMeters { get; set; }
    public double DurationSeconds { get; set; }
}

public class RecordVisitRequestDto
{
    public string? PlaceId { get; set; }

    [Required]
    public string Title { get; set; } = string.Empty;

    public string? PrimaryType { get; set; }
    public string? Address { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public double? DistanceKm { get; set; }

    [Required]
    public DateTime StartedAt { get; set; }

    [Required]
    public DateTime EndedAt { get; set; }
}

public class VisitLogDto
{
    public string LogId { get; set; } = string.Empty;
    public string? PlaceId { get; set; }
    public string? Title { get; set; }
    public string? PrimaryType { get; set; }
    public string? Address { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public double? DistanceKm { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? EndedAt { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? PhotoUrl { get; set; }
    public string? PhotoAttribution { get; set; }
}