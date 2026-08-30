namespace ExploreMy.Api.Domain.Entities;

public class FavouritePlace
{
    public int FavouritePlaceId { get; set; }
    public int UserId { get; set; }
    public string? PlaceId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string PrimaryType { get; set; } = string.Empty;
    public string? Address { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public DateTime? LastVisitAt { get; set; }
    public DateTime CreatedAt { get; set; }

    // Rich-detail snapshot from hidden_place_cache, taken at favourite-time (Google-sourced only)
    public double? Rating { get; set; }
    public int UserRatingCount { get; set; } = 0;
    public int? PriceLevel { get; set; }
    public string? BusinessStatus { get; set; }
    public string? GoogleMapsUri { get; set; }
    public string? NationalPhoneNumber { get; set; }
    public string? WebsiteUri { get; set; }
    public string? PhotosJson { get; set; }
    public string? RegularOpeningHoursJson { get; set; }

    // Set only when this favourite is sourced from the Recommended Places module.
    // Exactly one of PlaceId / RecommendPlaceId is set — enforced by
    // chk_favourite_place_source at the DB level.
    public string? RecommendPlaceId { get; set; }
}