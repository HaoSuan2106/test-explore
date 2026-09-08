using ExploreMy.Api.Application.HiddenPlace.Review;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;

namespace ExploreMy.Api.Infrastructure.Repositories.HiddenPlace.Review;

public class ReviewPhotoMySqlRepository : IReviewPhotoRepository
{
    private readonly MySqlDbContext _dbContext;

    public ReviewPhotoMySqlRepository(MySqlDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<List<ReviewPhoto>> GetByReviewIdAsync(long reviewId)
    {
        return await _dbContext.ReviewPhotos
            .Where(p => p.ReviewId == reviewId)
            .OrderBy(p => p.DisplayOrder)
            .ToListAsync();
    }

    public Task<Dictionary<string, ReviewCoverPhoto>> GetCoverPhotosByGooglePlaceIdsAsync(
        IReadOnlyCollection<string> googlePlaceIds)
        => GetCoverPhotosAsync(googlePlaceIds, forGooglePlaces: true);

    public Task<Dictionary<string, ReviewCoverPhoto>> GetCoverPhotosByRecommendPlaceIdsAsync(
        IReadOnlyCollection<string> recommendPlaceIds)
        => GetCoverPhotosAsync(recommendPlaceIds, forGooglePlaces: false);

    /// <summary>
    /// Shared body of the two lookups above. A review points at exactly one of the two id columns
    /// (ReviewService.ValidateTarget enforces it), so the only difference between them is which
    /// column identifies the place - everything after that is the same work.
    /// </summary>
    private async Task<Dictionary<string, ReviewCoverPhoto>> GetCoverPhotosAsync(
        IReadOnlyCollection<string> placeIds, bool forGooglePlaces)
    {
        if (placeIds is null || placeIds.Count == 0)
        {
            return new Dictionary<string, ReviewCoverPhoto>(StringComparer.Ordinal);
        }

        var ids = placeIds.Distinct(StringComparer.Ordinal).ToList();

        // The id filter is built in C# rather than as a ternary inside the query, so each branch
        // translates to a plain WHERE ... IN (...) instead of a CASE around the whole thing.
        var reviews = forGooglePlaces
            ? _dbContext.Reviews.Where(r => r.GooglePlaceId != null && ids.Contains(r.GooglePlaceId))
            : _dbContext.Reviews.Where(r => r.RecommendPlaceId != null && ids.Contains(r.RecommendPlaceId));

        // One query for every candidate place, not one per place: a search hands us dozens of
        // place ids at a time and this runs on the way out of every search.
        //
        // The user is joined in only for the credit line, and joined LEFT so a review whose author
        // row has gone missing still contributes its picture instead of dropping out of the result.
        var rows = await (
            from photo in _dbContext.ReviewPhotos
            join review in reviews
                on photo.ReviewId equals review.ReviewId
            join user in _dbContext.Users
                on review.UserId equals user.UserId into authors
            from author in authors.DefaultIfEmpty()
            where review.Status == "ACTIVE"
            select new
            {
                review.GooglePlaceId,
                review.RecommendPlaceId,
                photo.PhotoUrl,
                photo.DisplayOrder,
                photo.ReviewPhotoId,
                ReviewCreatedAt = review.CreatedAt,
                Username = author != null ? author.Username : null
            })
            .AsNoTracking()
            .ToListAsync();

        // Picked in memory rather than in SQL: "the newest review's first photo" is a per-group
        // top-1, which MySQL would need a window function or a correlated subquery for, over a set
        // that is at most a few photos per place. Newest first so a place's cover follows what
        // people are posting now; DisplayOrder then decides within that review, because the first
        // photo is the one its author chose to lead with.
        return rows
            .Where(row => !string.IsNullOrWhiteSpace(row.PhotoUrl))
            .Select(row => new
            {
                PlaceId = forGooglePlaces ? row.GooglePlaceId : row.RecommendPlaceId,
                row.PhotoUrl,
                row.DisplayOrder,
                row.ReviewPhotoId,
                row.ReviewCreatedAt,
                row.Username
            })
            .Where(row => !string.IsNullOrWhiteSpace(row.PlaceId))
            .GroupBy(row => row.PlaceId!, StringComparer.Ordinal)
            .ToDictionary(
                group => group.Key,
                group =>
                {
                    var cover = group
                        .OrderByDescending(row => row.ReviewCreatedAt)
                        .ThenBy(row => row.DisplayOrder)
                        .ThenBy(row => row.ReviewPhotoId)
                        .First();

                    return new ReviewCoverPhoto(
                        cover.PhotoUrl,
                        string.IsNullOrWhiteSpace(cover.Username)
                            ? null
                            : $"Photo by {cover.Username}");
                },
                StringComparer.Ordinal);
    }

    public async Task AddAsync(ReviewPhoto photo)
    {
        await _dbContext.ReviewPhotos.AddAsync(photo);
        await _dbContext.SaveChangesAsync();
    }

    public async Task AddRangeAsync(List<ReviewPhoto> photos)
    {
        await _dbContext.ReviewPhotos.AddRangeAsync(photos);
        await _dbContext.SaveChangesAsync();
    }

    public async Task DeleteAsync(ReviewPhoto photo)
    {
        _dbContext.ReviewPhotos.Remove(photo);
        await _dbContext.SaveChangesAsync();
    }

    public async Task DeleteByReviewIdAsync(long reviewId)
    {
        var photos = await _dbContext.ReviewPhotos
            .Where(p => p.ReviewId == reviewId)
            .ToListAsync();

        if (photos.Count == 0)
            return;

        _dbContext.ReviewPhotos.RemoveRange(photos);
        await _dbContext.SaveChangesAsync();
    }
}