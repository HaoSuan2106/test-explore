namespace ExploreMy.Api.Domain.Entities;

public class Community
{
    public int CommunityId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Area { get; set; }
    /// State/federal-territory this community's area falls under (e.g. "Selangor"). Separate from
    /// Area (the district/neighbourhood name) so the app can display "State, District" and filter
    /// Browse Community by state without parsing Area.
    public string? State { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? ImageUrl { get; set; }
    public DateTime CreatedAt { get; set; }
}
