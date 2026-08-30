using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.Application.HiddenPlace.Review;

public interface IReviewReportRepository
{
    Task<bool> ExistsAsync(long reviewId, int userId);

    Task AddAsync(ReviewReport report);

    Task<int> CountByReviewIdAsync(long reviewId);
}