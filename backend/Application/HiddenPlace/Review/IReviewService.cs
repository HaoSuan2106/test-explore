using ExploreMy.Api.DTOs.HiddenPlace;
using Microsoft.AspNetCore.Http;

namespace ExploreMy.Api.Application.HiddenPlace.Review;

public interface IReviewService
{
    Task<HiddenPlaceReviewDto?> GetByIdAsync(long reviewId);

    Task<List<HiddenPlaceReviewDto>> GetByGooglePlaceIdAsync(
        string googlePlaceId);

    Task<List<HiddenPlaceReviewDto>> GetByRecommendPlaceIdAsync(
        string recommendPlaceId);

    Task<HiddenPlaceReviewDto?> GetUserReviewForGooglePlaceAsync(
        int userId,
        string googlePlaceId);

    Task<HiddenPlaceReviewDto?> GetUserReviewForRecommendPlaceAsync(
        int userId,
        string recommendPlaceId);

    Task<HiddenPlaceReviewDto> CreateAsync(
        int userId,
        CreateHiddenPlaceReviewRequestDto request);

    Task<HiddenPlaceReviewDto> UpdateAsync(
        int userId,
        long reviewId,
        UpdateHiddenPlaceReviewRequestDto request);

    Task DeleteAsync(
        int userId,
        long reviewId);

    Task<List<HiddenPlaceReviewPhotoDto>> UploadPhotosAsync(
    int userId,
    long reviewId,
    List<IFormFile> files);
}