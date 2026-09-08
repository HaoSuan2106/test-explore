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

    public Task<Dictionary<string, PlaceReviewStats>> GetStatsByGooglePlaceIdsAsync(
        IReadOnlyCollection<string> googlePlaceIds)
        => GetStatsAsync(googlePlaceIds, forGooglePlaces: true);

    public Task<Dictionary<string, PlaceReviewStats>> GetStatsByRecommendPlaceIdsAsync(
        IReadOnlyCollection<string> recommendPlaceIds)
        => GetStatsAsync(recommendPlaceIds, forGooglePlaces: false);

    /// <summary>
    /// Shared body of the two stat lookups. A review points at exactly one of the two id columns
    /// (ReviewService.ValidateTarget enforces it), so the only difference is which one is grouped on.
    ///
    /// Counting and averaging happen in SQL rather than by loading the rows: this runs on every
    /// search, and the rows themselves - comments, timestamps, authors - are of no interest here.
    /// </summary>
    private async Task<Dictionary<string, PlaceReviewStats>> GetStatsAsync(
        IReadOnlyCollection<string> placeIds, bool forGooglePlaces)
    {
        if (placeIds is null || placeIds.Count == 0)
        {
            return new Dictionary<string, PlaceReviewStats>(StringComparer.Ordinal);
        }

        var ids = placeIds.Distinct(StringComparer.Ordinal).ToList();

        var active = _dbContext.Reviews.AsNoTracking().Where(r => r.Status == "ACTIVE");

        var grouped = forGooglePlaces
            ? active
                .Where(r => r.GooglePlaceId != null && ids.Contains(r.GooglePlaceId))
                .GroupBy(r => r.GooglePlaceId!)
            : active
                .Where(r => r.RecommendPlaceId != null && ids.Contains(r.RecommendPlaceId))
                .GroupBy(r => r.RecommendPlaceId!);

        var rows = await grouped
            .Select(g => new
            {
                PlaceId = g.Key,
                ReviewCount = g.Count(),
                AverageRating = g.Average(r => r.Rating)
            })
            .ToListAsync();

        return rows.ToDictionary(
            row => row.PlaceId,
            row => new PlaceReviewStats(row.ReviewCount, (double)row.AverageRating),
            StringComparer.Ordinal);
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
                ProfilePictureUrl = user.ProfilePictureUrl,
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
                ProfilePictureUrl = user.ProfilePictureUrl,
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
                ProfilePictureUrl = user.ProfilePictureUrl,
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
                ProfilePictureUrl = user.ProfilePictureUrl,
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