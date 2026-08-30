using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.Application.HiddenPlace.Review;

public interface IReviewPhotoRepository
{
    Task<List<ReviewPhoto>> GetByReviewIdAsync(long reviewId);

    Task AddAsync(ReviewPhoto photo);

    Task AddRangeAsync(List<ReviewPhoto> photos);

    Task DeleteAsync(ReviewPhoto photo);

    Task DeleteByReviewIdAsync(long reviewId);
}