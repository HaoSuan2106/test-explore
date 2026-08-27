using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.HiddenPlaceContribution;

public interface IHiddenPlaceContributionService
{
    Task<List<RecommendedPlaceSummaryDto>> GetMyPlacesAsync(int currentUserId);
    Task<RecommendedPlaceDetailsDto> GetPlaceDetailsAsync(int currentUserId, string submissionId);
    Task<SubmitRecommendedPlaceResponseDto> SubmitPlaceAsync(int currentUserId, SubmitRecommendedPlaceRequestDto request);
    Task<WithdrawRecommendedPlaceResponseDto> WithdrawPlaceAsync(int currentUserId, string submissionId);
    Task<ToggleVerificationResponseDto> ToggleVerificationAsync(int currentUserId, string submissionId, bool verify);
    Task<ReportRecommendedPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason);
    IReadOnlyList<string> GetReportReasons();
}