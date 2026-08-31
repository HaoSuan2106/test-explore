namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A user's recommendation submission. References a canonical
/// <see cref="RecommendPlace"/> row via <see cref="RecommendPlaceId"/>; the
/// submission itself carries only submission-specific data (status,
/// timestamps). Name, primary type, description and coordinates live on the
/// referenced <c>recommended_places</c> row and must NOT be duplicated here.
/// Maps to the <c>place_submissions</c> table.
/// </summary>
public class PlaceSubmission
{
    public string SubmissionId { get; set; } = Guid.NewGuid().ToString();
    public int SubmitterId { get; set; }

    /// <summary>FK → recommended_places(recommend_place_id).</summary>
    public string RecommendPlaceId { get; set; } = string.Empty;
    public string Status { get; set; } = RecommendedPlaceStatus.UnderVoting;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public User? Submitter { get; set; }
    public RecommendPlace? Place { get; set; }
    public ICollection<PlaceSubmissionVerification> Verifications { get; set; } = new List<PlaceSubmissionVerification>();
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

/// <summary>
/// Supported place-report reasons for recommended places. These are served
/// via the GET /api/recommended-places/report-reasons endpoint.
/// (Derived from the task specification; confirm with product.)
/// </summary>
public static class PlaceReportReasons
{
    public const string Closed = "CLOSED";
    public const string WrongInformation = "WRONG_INFORMATION";
    public const string Duplicate = "DUPLICATE";
    public const string DoesNotExist = "DOES_NOT_EXIST";
    public const string Other = "OTHER";

    public static readonly IReadOnlyList<string> All =
    [
        Closed,
        WrongInformation,
        Duplicate,
        DoesNotExist,
        Other,
    ];

    public static bool Contains(string? reason) => All.Contains(reason ?? string.Empty);
}
