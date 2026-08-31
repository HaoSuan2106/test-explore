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

    /// <summary>Updates an existing recommendation (both tables) — see HiddenPlaceContributionService.</summary>
    Task<SubmitRecommendedPlaceResponseDto> UpdateRecommendationAsync(int currentUserId, string submissionId, SubmitRecommendedPlaceRequestDto request);
    Task<WithdrawRecommendedPlaceResponseDto> WithdrawPlaceAsync(int currentUserId, string submissionId);
    Task<ToggleVerificationResponseDto> ToggleVerificationAsync(int currentUserId, string submissionId, bool verify);

    /// <summary>Records an anonymous place report against a recommended place.</summary>
    Task<ReportPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason);

    /// <summary>Uploads a recommended-place photo and returns its public URL.</summary>
    Task<string> UploadPlaceImageAsync(int currentUserId, Stream fileStream, string fileName, string contentType);

    /// <summary>
    /// Distinct Primary Type options for the Recommend Place form, read from
    /// <c>hidden_place_cache.primary_type</c> (read-only data source).
    /// </summary>
    Task<List<string>> GetPrimaryTypeOptionsAsync();

    /// <summary>List VERIFIED recommended places for public discovery (REQ502_20).</summary>
    Task<List<RecommendedPlaceSummaryDto>> GetPublishedPlacesAsync();
}