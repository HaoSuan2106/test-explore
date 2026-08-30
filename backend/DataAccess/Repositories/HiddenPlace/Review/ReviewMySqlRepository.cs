using ExploreMy.Api.Application.HiddenPlace.Review;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;
using ReviewEntity = ExploreMy.Api.Domain.Entities.Review;
using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Infrastructure.Repositories.HiddenPlace.Review;

public class ReviewMySqlRepository : IReviewRepository
{
    private readonly MySqlDbContext _dbContext;

    public ReviewMySqlRepository(MySqlDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<ReviewEntity?> GetByIdAsync(long reviewId)
    {
        return await _dbContext.Reviews
            .FirstOrDefaultAsync(r =>
                r.ReviewId == reviewId &&
                r.Status == "ACTIVE");
    }

    public async Task<List<HiddenPlaceReviewDto>> GetByGooglePlaceIdAsync(
    string googlePlaceId)
    {
        return await (
            from review in _dbContext.Reviews
            join user in _dbContext.Users
                on review.UserId equals user.UserId
            where review.GooglePlaceId == googlePlaceId
                  && review.Status == "ACTIVE"
            orderby review.CreatedAt descending
            select new HiddenPlaceReviewDto
            {
                ReviewId = review.ReviewId,
                GooglePlaceId = review.GooglePlaceId,
                RecommendPlaceId = review.RecommendPlaceId,
                UserId = review.UserId,
                Username = user.Username,
                Rating = review.Rating,
                Comment = review.Comment,
                CreatedAt = review.CreatedAt,
                UpdatedAt = review.UpdatedAt,
                Status = review.Status
            }
        ).ToListAsync();
    }

    public async Task<List<HiddenPlaceReviewDto>> GetByRecommendPlaceIdAsync(
    string recommendPlaceId)
    {
        return await (
            from review in _dbContext.Reviews
            join user in _dbContext.Users
                on review.UserId equals user.UserId
            where review.RecommendPlaceId == recommendPlaceId
                  && review.Status == "ACTIVE"
            orderby review.CreatedAt descending
            select new HiddenPlaceReviewDto
            {
                ReviewId = review.ReviewId,
                GooglePlaceId = review.GooglePlaceId,
                RecommendPlaceId = review.RecommendPlaceId,
                UserId = review.UserId,
                Username = user.Username,
                Rating = review.Rating,
                Comment = review.Comment,
                CreatedAt = review.CreatedAt,
                UpdatedAt = review.UpdatedAt,
                Status = review.Status
            }
        ).ToListAsync();
    }

    public async Task<HiddenPlaceReviewDto?> GetUserReviewForGooglePlaceAsync(
    int userId,
    string googlePlaceId)
    {
        return await (
            from review in _dbContext.Reviews
            join user in _dbContext.Users
                on review.UserId equals user.UserId
            where review.UserId == userId
                  && review.GooglePlaceId == googlePlaceId
                  && review.Status == "ACTIVE"
            select new HiddenPlaceReviewDto
            {
                ReviewId = review.ReviewId,
                GooglePlaceId = review.GooglePlaceId,
                RecommendPlaceId = review.RecommendPlaceId,
                UserId = review.UserId,
                Username = user.Username,
                Rating = review.Rating,
                Comment = review.Comment,
                CreatedAt = review.CreatedAt,
                UpdatedAt = review.UpdatedAt,
                Status = review.Status
            }
        ).FirstOrDefaultAsync();
    }

    public async Task<HiddenPlaceReviewDto?> GetUserReviewForRecommendPlaceAsync(
    int userId,
    string recommendPlaceId)
    {
        return await (
            from review in _dbContext.Reviews
            join user in _dbContext.Users
                on review.UserId equals user.UserId
            where review.UserId == userId
                  && review.RecommendPlaceId == recommendPlaceId
                  && review.Status == "ACTIVE"
            select new HiddenPlaceReviewDto
            {
                ReviewId = review.ReviewId,
                GooglePlaceId = review.GooglePlaceId,
                RecommendPlaceId = review.RecommendPlaceId,
                UserId = review.UserId,
                Username = user.Username,
                Rating = review.Rating,
                Comment = review.Comment,
                CreatedAt = review.CreatedAt,
                UpdatedAt = review.UpdatedAt,
                Status = review.Status
            }
        ).FirstOrDefaultAsync();
    }

    public async Task AddAsync(ReviewEntity review)
    {
        await _dbContext.Reviews.AddAsync(review);
        await _dbContext.SaveChangesAsync();
    }

    public async Task UpdateAsync(ReviewEntity review)
    {
        _dbContext.Reviews.Update(review);
        await _dbContext.SaveChangesAsync();
    }

    public async Task DeleteAsync(ReviewEntity review)
    {
        _dbContext.Reviews.Remove(review);
        await _dbContext.SaveChangesAsync();
    }
}