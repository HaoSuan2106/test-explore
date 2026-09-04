using ExploreMy.Api.DTOs.HiddenPlace;
using Microsoft.AspNetCore.Http;

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
    Task<ToggleVerificationResponseDto> ToggleVerificationAsync(int currentUserId, string submissionId, bool verify);

    /// <summary>Records an anonymous place report against a recommended place.</summary>
    Task<ReportPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason);

    /// <summary>
    /// Returns whether the CURRENT user has already reported the given place.
    /// Accepts both a recommended-place submission GUID and a Google-sourced
    /// place_id; resolution follows the same identifier mapping as the report
    /// endpoint (see <see cref="IHiddenPlaceContributionService.GetPlaceReportStatusAsync"/>).
    /// </summary>
    Task<PlaceReportStatusResponseDto> GetPlaceReportStatusAsync(int currentUserId, string placeId);

    /// <summary>
    /// OWNER WITHDRAWAL — the submitter/owner moves their own recommendation to
    /// <c>WITHDRAWN</c> (place_submissions.status). Only the owner may withdraw;
    /// a non-owner is rejected with <see cref="ForbiddenException"/>.
    /// </summary>
    Task<SubmitRecommendedPlaceResponseDto> WithdrawRecommendationAsync(int currentUserId, string submissionId);

    /// <summary>Uploads a recommended-place photo and returns its public URL.</summary>
    Task<string> UploadPlaceImageAsync(int currentUserId, Stream fileStream, string fileName, string contentType);

    /// <summary>
    /// Distinct Primary Type options for the Recommend Place form, read from
    /// <c>hidden_place_cache.primary_type</c> (read-only data source).
    /// </summary>
    Task<List<string>> GetPrimaryTypeOptionsAsync();

    /// <summary>List VERIFIED recommended places for public discovery (REQ502_20).</summary>
    Task<List<RecommendedPlaceSummaryDto>> GetPublishedPlacesAsync();

    // ---------------------------------------------------------------
    // Review — delegates to ReviewService. Named "…Review…" rather than
    // the bare CreateAsync/UpdateAsync/DeleteAsync of IReviewService, so
    // that on a facade that also manages places it is unambiguous what
    // is being created or deleted.
    // ---------------------------------------------------------------

    Task<HiddenPlaceReviewDto?> GetReviewByIdAsync(long reviewId);
    Task<List<HiddenPlaceReviewDto>> GetReviewsByGooglePlaceIdAsync(string googlePlaceId);
    Task<List<HiddenPlaceReviewDto>> GetReviewsByRecommendPlaceIdAsync(string recommendPlaceId);
    Task<HiddenPlaceReviewDto?> GetUserReviewForGooglePlaceAsync(int userId, string googlePlaceId);
    Task<HiddenPlaceReviewDto?> GetUserReviewForRecommendPlaceAsync(int userId, string recommendPlaceId);
    Task<HiddenPlaceReviewDto> CreateReviewAsync(int userId, CreateHiddenPlaceReviewRequestDto request);
    Task<HiddenPlaceReviewDto> UpdateReviewAsync(int userId, long reviewId, UpdateHiddenPlaceReviewRequestDto request);
    Task DeleteReviewAsync(int userId, long reviewId);
    Task<List<HiddenPlaceReviewPhotoDto>> UploadReviewPhotosAsync(int userId, long reviewId, List<IFormFile> files);
    Task DeleteReviewPhotoAsync(int userId, long reviewId, long reviewPhotoId);
    Task ReportReviewAsync(int userId, long reviewId, string reason);
}