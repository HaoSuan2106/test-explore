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
    public string Category { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
