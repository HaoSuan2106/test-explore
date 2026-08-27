namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A report submitted by an authenticated user against a recommended place,
/// carrying one of the predefined report reasons. A report is terminal: it is
/// recorded and cannot be withdrawn (frozen decision D5). A place is removed
/// from public view (REPORTED_CLOSED) once it receives at least five unique
/// ACTIVE reports.
/// Maps to the <c>recommended_place_reports</c> table.
/// </summary>
public class RecommendedPlaceReport
{
    public string ReportId { get; set; } = Guid.NewGuid().ToString();
    public string SubmissionId { get; set; } = string.Empty;
    public int ReporterId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string Status { get; set; } = RecommendedPlaceReportStatus.Active;
    public DateTime CreatedAt { get; set; }

    // Navigation
    public RecommendedPlace? Place { get; set; }
    public User? Reporter { get; set; }
}

public static class RecommendedPlaceReportStatus
{
    public const string Active = "ACTIVE";
}

public static class RecommendedPlaceReportReasons
{
    public const string InappropriateOrMisleadingImagery = "Inappropriate or misleading location imagery";
    public const string CommercialSpamPromotion = "Commercial Spam Promotion";
    public const string UnauthorizedPrivatePropertyAccess = "Unauthorized Private Property Access";
    public const string InaccurateOrOutdatedPlaceDetails = "Inaccurate or outdated place details";
    public const string OtherViolation = "Other violation";

    public static readonly IReadOnlyList<string> All = new[]
    {
        InappropriateOrMisleadingImagery,
        CommercialSpamPromotion,
        UnauthorizedPrivatePropertyAccess,
        InaccurateOrOutdatedPlaceDetails,
        OtherViolation,
    };
}