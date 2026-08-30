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