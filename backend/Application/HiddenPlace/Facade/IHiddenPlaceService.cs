using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.Facade;

public interface IHiddenPlaceService
{
    /// <summary>Fetches nearby places from Google Places API and returns them ranked by hidden-gem score.</summary>
    Task<List<HiddenPlaceResponseItemDto>> DiscoverHiddenPlacesAsync(
        DiscoverHiddenPlaceRequestDto request,
        CancellationToken cancellationToken = default);
    Task<List<RecommendedPlaceSummaryDto>> GetMyPlacesAsync(int currentUserId);
    Task<RecommendedPlaceDetailsDto> GetPlaceDetailsAsync(int currentUserId, string submissionId);
    Task<SubmitRecommendedPlaceResponseDto> SubmitPlaceAsync(int currentUserId, SubmitRecommendedPlaceRequestDto request);
    Task<WithdrawRecommendedPlaceResponseDto> WithdrawPlaceAsync(int currentUserId, string submissionId);
    Task<ToggleVerificationResponseDto> ToggleVerificationAsync(int currentUserId, string submissionId, bool verify);
    Task<ReportRecommendedPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason);
    IReadOnlyList<string> GetReportReasons();

    /// <summary>List VERIFIED recommended places for public discovery (REQ502_20).</summary>
    Task<List<RecommendedPlaceSummaryDto>> GetPublishedPlacesAsync();
}