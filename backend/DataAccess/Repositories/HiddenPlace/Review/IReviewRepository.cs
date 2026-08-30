using ExploreMy.Api.Domain.Entities;
using ReviewEntity = ExploreMy.Api.Domain.Entities.Review;
using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.Review;

public interface IReviewRepository
{
    Task<ReviewEntity?> GetByIdAsync(long reviewId);

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

    Task AddAsync(ReviewEntity review);

    Task UpdateAsync(ReviewEntity review);

    Task DeleteAsync(ReviewEntity review);
}