namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A tourism place that community posts can be tagged with.
/// Maps to the <c>places</c> table (shared module dependency).
/// </summary>
public class Place
{
    public string PlaceId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public string? Description { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public string PrimaryType { get; set; } = string.Empty; 
    public double? Rating { get; set; }
    public int UserRatingCount { get; set; } = 0;
    public int? PriceLevel { get; set; }
    public string? BusinessStatus { get; set; }
    public string? GoogleMapsUri { get; set; }
    public string? NationalPhoneNumber { get; set; }
    public string? WebsiteUri { get; set; }
    public string? PhotosJson { get; set; }
    public string? RegularOpeningHoursJson { get; set; }
    public string? ShortFormattedAddress { get; set; }
    public string? PrimaryTypeDisplayName { get; set; }
    public string? AccessibilityOptionsJson { get; set; }
    public string? AddressComponentsJson { get; set; }
    public string? GoogleMapsLinksJson { get; set; }
    public string? ViewportJson { get; set; }
    public DateOnly? OpeningDate { get; set; }
}
