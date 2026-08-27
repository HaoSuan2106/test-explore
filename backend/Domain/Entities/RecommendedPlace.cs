namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A tourism place recommended by an authenticated user. The place goes through
/// community verification (voting) and can be reported if inappropriate.
/// Maps to the <c>recommended_places</c> table.
/// </summary>
public class RecommendedPlace
{
    public string SubmissionId { get; set; } = Guid.NewGuid().ToString();
    public int SubmitterId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string LocationAddress { get; set; } = string.Empty;
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public string Category { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Status { get; set; } = RecommendedPlaceStatus.UnderVoting;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public User? Submitter { get; set; }
    public ICollection<RecommendedPlaceVerification> Verifications { get; set; } = new List<RecommendedPlaceVerification>();
    public ICollection<RecommendedPlaceReport> Reports { get; set; } = new List<RecommendedPlaceReport>();
}

public static class RecommendedPlaceStatus
{
    public const string UnderVoting = "UNDER_VOTING";
    public const string Verified = "VERIFIED";
    public const string ReportedClosed = "REPORTED_CLOSED";
    public const string Withdrawn = "WITHDRAWN";
}

/// <summary>
/// The closed set of accepted recommendation categories (L-11). Must match the
/// dropdown offered in the Recommend Place screen.
/// </summary>
public static class RecommendedPlaceCategories
{
    public const string Cafe = "Café";
    public const string Restaurant = "Restaurant";
    public const string ScenicPoint = "Scenic Point";
    public const string HistoricalSite = "Historical Site";
    public const string NatureAndParks = "Nature & Parks";
    public const string ShoppingAndMarket = "Shopping & Market";

    public static readonly IReadOnlyList<string> All =
    [
        Cafe,
        Restaurant,
        ScenicPoint,
        HistoricalSite,
        NatureAndParks,
        ShoppingAndMarket,
    ];

    public static bool Contains(string? category) => All.Contains(category ?? string.Empty);
}

public static class RecommendedPlaceThresholds
{
    /// <summary>Verification votes required to move from UNDER_VOTING to VERIFIED.</summary>
    public const int RequiredVerifications = 5;

    /// <summary>Unique active reports required to move to REPORTED_CLOSED.</summary>
    public const int HideThreshold = 5;

    /// <summary>Proximity duplicate-check radius in meters (REQ502_5).</summary>
    public const double ProximityRadiusMeters = 100.0;
}