namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A report submitted by an authenticated user against a community post,
/// carrying one of the predefined report reasons.
/// Maps to the <c>community_post_reports</c> table.
///
/// Lifecycle: a report is created as ACTIVE (withdrawn_at = NULL). A reporter
/// may withdraw their own report, moving it to WITHDRAWN and stamping
/// withdrawn_at with the withdrawal timestamp. Multiple reports from the same
/// user on the same post are allowed (the schema has no unique index on
/// post_id + reporter_id).
/// </summary>
public class PostReport
{
    public string ReportId { get; set; } = Guid.NewGuid().ToString();
    public string PostId { get; set; } = string.Empty;
    public int ReporterId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string Status { get; set; } = PostReportStatus.Active;
    public DateTime CreatedAt { get; set; }
    public DateTime? WithdrawnAt { get; set; }

    // Navigation
    public Post? Post { get; set; }
    public User? Reporter { get; set; }
}

public static class PostReportStatus
{
    public const string Active = "ACTIVE";
    public const string Withdrawn = "WITHDRAWN";
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
