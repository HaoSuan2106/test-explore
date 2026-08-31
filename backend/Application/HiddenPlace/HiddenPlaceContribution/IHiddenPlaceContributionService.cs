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
    Task<WithdrawRecommendedPlaceResponseDto> WithdrawPlaceAsync(int currentUserId, string submissionId);
    Task<ToggleVerificationResponseDto> ToggleVerificationAsync(int currentUserId, string submissionId, bool verify);

    /// <summary>
    /// Records an ANONYMOUS place report against a recommended place. The report is stored in
    /// <c>hidden_place_suppression</c> (aggregate report_count, no reporter identity). When the
    /// report count reaches <see cref="RecommendedPlaceThresholds.HideThreshold"/> the submission
    /// status is moved to <see cref="RecommendedPlaceStatus.ReportedClosed"/>.
    /// </summary>
    Task<ReportPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason);

    /// <summary>
    /// Distinct Primary Type options for the Recommend Place form, read from
    /// <c>hidden_place_cache.primary_type</c> (read-only data source).
    /// </summary>
    Task<List<string>> GetPrimaryTypeOptionsAsync();
}