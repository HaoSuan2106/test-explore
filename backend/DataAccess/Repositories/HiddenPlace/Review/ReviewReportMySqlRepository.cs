using ExploreMy.Api.Application.HiddenPlace.Review;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;

namespace ExploreMy.Api.Infrastructure.Repositories.HiddenPlace.Review;

public class ReviewReportMySqlRepository : IReviewReportRepository
{
    private readonly MySqlDbContext _dbContext;

    public ReviewReportMySqlRepository(MySqlDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<bool> ExistsAsync(
        long reviewId,
        int userId)
    {
        return await _dbContext.ReviewReports
            .AnyAsync(r =>
                r.ReviewId == reviewId &&
                r.UserId == userId);
    }

    public async Task AddAsync(ReviewReport report)
    {
        await _dbContext.ReviewReports.AddAsync(report);
        await _dbContext.SaveChangesAsync();
    }

    public async Task<int> CountByReviewIdAsync(long reviewId)
    {
        return await _dbContext.ReviewReports
            .CountAsync(r => r.ReviewId == reviewId);
    }
}