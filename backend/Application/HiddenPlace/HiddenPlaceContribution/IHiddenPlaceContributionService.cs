using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.HiddenPlaceContribution;

public interface IHiddenPlaceContributionService
{
    Task<string> UploadPlaceImageAsync(int currentUserId, Stream fileStream, string fileName, string contentType);
    Task<List<RecommendedPlaceSummaryDto>> GetMyPlacesAsync(int currentUserId);
    Task<RecommendedPlaceDetailsDto> GetPlaceDetailsAsync(int currentUserId, string submissionId);
    Task<SubmitRecommendedPlaceResponseDto> SubmitPlaceAsync(int currentUserId, SubmitRecommendedPlaceRequestDto request);

    /// <summary>
    /// Updates an existing recommendation (both halves — canonical place data AND
    /// submission timestamp) in one transaction. Ownership is enforced: only the
    /// submitter may edit, and only while the submission is still UNDER_VOTING.
    /// </summary>
    Task<SubmitRecommendedPlaceResponseDto> UpdateRecommendationAsync(int currentUserId, string submissionId, SubmitRecommendedPlaceRequestDto request);
    Task<ToggleVerificationResponseDto> ToggleVerificationAsync(int currentUserId, string submissionId, bool verify);

    /// <summary>
    /// OWNER WITHDRAWAL — a COMPLETELY SEPARATE function from place reporting.
    /// The submitter/owner moves their own recommendation to
    /// <see cref="RecommendedPlaceStatus.Withdrawn"/> (place_submissions.status).
    /// Only the owner may withdraw; a non-owner is rejected.
    /// </summary>
    Task<SubmitRecommendedPlaceResponseDto> WithdrawRecommendationAsync(int currentUserId, string submissionId);

    /// <summary>
    /// Records an ANONYMOUS place report against a recommended place. The report is stored in
    /// <c>hidden_place_suppression</c> (aggregate report_count, no reporter identity). When the
    /// report count reaches <see cref="RecommendedPlaceThresholds.HideThreshold"/> the submission
    /// status is moved to <see cref="RecommendedPlaceStatus.ReportedClosed"/>.
    /// </summary>
    Task<ReportPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason);

    /// <summary>
    /// Returns whether the CURRENT user has already reported the given place.
    /// Accepts BOTH place identities used by the report flow:
    /// <list type="bullet">
    /// <item>a recommended-place submission GUID (place_submissions.submission_id) — resolved to the
    /// canonical <c>recommend_place_id</c> before the suppression check, exactly like the report
    /// endpoint persists it; or</item>
    /// <item>a Google-sourced <c>place_id</c> (no submission row) — checked directly against
    /// <c>hidden_place_suppression.place_id</c>.</item>
    /// </list>
    /// Never confuses the two: the lookup is by submission first, then falls back to the raw id.
    /// </summary>
    Task<PlaceReportStatusResponseDto> GetPlaceReportStatusAsync(int currentUserId, string placeId);

    /// <summary>
    /// Distinct Primary Type options for the Recommend Place form, read from
    /// <c>hidden_place_cache.primary_type</c> (read-only data source).
    /// </summary>
    Task<List<string>> GetPrimaryTypeOptionsAsync();

    /// <summary>
    /// List recommended places that reached the VERIFIED status and are publicly viewable.
    /// Published places are a Contribution concern (submission status, verification counts,
    /// community visibility) — the owning service manages the listing.
    /// </summary>
    Task<List<RecommendedPlaceSummaryDto>> GetPublishedPlacesAsync();
}