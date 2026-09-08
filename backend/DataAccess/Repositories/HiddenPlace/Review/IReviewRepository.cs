using ExploreMy.Api.Domain.Entities;
using ReviewEntity = ExploreMy.Api.Domain.Entities.Review;
using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.Review;

/// <summary>
/// What our own users collectively think of one place: how many ACTIVE reviews it has here and what
/// they average. This is the app's own half of the discovery algorithm's inputs - see
/// PlaceCandidate.EffectiveRating and CommunityPlaceScorer.
/// </summary>
public sealed record PlaceReviewStats(int ReviewCount, double AverageRating);

public interface IReviewRepository
{
    Task<ReviewEntity?> GetByIdAsync(long reviewId);

    /// <summary>
    /// Review count and average rating per Google place, for a batch of place ids.
    ///
    /// Batched because it runs once per search over every candidate the search found; one query per
    /// place would put hundreds of round-trips in front of every map load. Places nobody has
    /// reviewed here are absent from the dictionary rather than mapped to a zero row.
    ///
    /// Only ACTIVE reviews are counted - a review removed by reports (status REMOVED) or deleted by
    /// its author must stop influencing the ranking, not keep voting from the grave.
    /// </summary>
    Task<Dictionary<string, PlaceReviewStats>> GetStatsByGooglePlaceIdsAsync(
        IReadOnlyCollection<string> googlePlaceIds);

    /// <summary>
    /// The same, for community places, keyed by <c>recommend_place_id</c> - the canonical place id a
    /// review stores, NOT the submission id the discovery API advertises as PlaceId.
    /// </summary>
    Task<Dictionary<string, PlaceReviewStats>> GetStatsByRecommendPlaceIdsAsync(
        IReadOnlyCollection<string> recommendPlaceIds);

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