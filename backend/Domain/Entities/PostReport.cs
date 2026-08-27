namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A report submitted by an authenticated user against a community post,
/// carrying one of the predefined report reasons. A report is terminal: it is
/// recorded and cannot be withdrawn (frozen decision D5).
/// Maps to the <c>community_post_reports</c> table.
/// </summary>
public class PostReport
{
    public string ReportId { get; set; } = Guid.NewGuid().ToString();
    public string PostId { get; set; } = string.Empty;
    public int ReporterId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string Status { get; set; } = PostReportStatus.Active;
    public DateTime CreatedAt { get; set; }

    // Navigation
    public Post? Post { get; set; }
    public User? Reporter { get; set; }
}

public static class PostReportStatus
{
    public const string Active = "ACTIVE";
}

public static class PostReportReasons
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
