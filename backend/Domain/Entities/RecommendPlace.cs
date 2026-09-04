namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// Canonical place information for the Recommend New Place module. Stores the
/// authoritative place data (name, coordinates, category type, etc.) exactly
/// once, independently of any particular user submission. Location is
/// represented ONLY by Latitude + Longitude (no address is stored).
/// Maps to the <c>recommended_places</c> table.
/// </summary>
public class RecommendPlace
{
    /// <summary>Primary key. For user submissions a new "usr-" + Guid is generated per submission.</summary>
    public string RecommendPlaceId { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = string.Empty;

    /// <summary>The primary Google-style type of the place; for user submissions mirrors the chosen category.</summary>
    public string PrimaryType { get; set; } = string.Empty;

    // No address field. Location is represented ONLY by Latitude + Longitude
    // (selected map coordinates) — reverse-geocoded addresses are not stored.
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double? Rating { get; set; }
    public int UserRatingCount { get; set; }
    public int? PriceLevel { get; set; }
    public string BusinessStatus { get; set; } = global::ExploreMy.Api.Domain.Entities.BusinessStatus.Operational;

    /// <summary>Canonical place description; nullable because user submissions may omit it.</summary>
    public string? Description { get; set; }

    /// <summary>JSON array of URLs for uploaded place photos. Nullable; stored as the JSON column <c>photo_json</c>.</summary>
    public string? PhotosJson { get; set; }

    // Navigation
    public ICollection<PlaceSubmission> Submissions { get; set; } = new List<PlaceSubmission>();
}
