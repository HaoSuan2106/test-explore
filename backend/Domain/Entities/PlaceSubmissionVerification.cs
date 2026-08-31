namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A community verification (vote) for a place submission. One row per user
/// per submission; the UNIQUE constraint on (submission_id, user_id) prevents
/// duplicate votes. A user may withdraw their verification by setting the
/// status to WITHDRAWN.
/// Maps to the <c>recommended_place_verifications</c> table.
/// </summary>
public class PlaceSubmissionVerification
{
    public string VerificationId { get; set; } = Guid.NewGuid().ToString();
    public string SubmissionId { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string Status { get; set; } = RecommendedPlaceVerificationStatus.Active;
    public DateTime CreatedAt { get; set; }

    // Navigation
    public PlaceSubmission? Submission { get; set; }
    public User? User { get; set; }
}

public static class RecommendedPlaceVerificationStatus
{
    public const string Active = "ACTIVE";
    public const string Withdrawn = "WITHDRAWN";
}
