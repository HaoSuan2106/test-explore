using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.Application.HiddenPlace.Review;

/// <summary>
/// One picture borrowed from a user's review, ready to stand in as a place's cover photo when
/// Google has none. <paramref name="Attribution"/> credits whoever took it, exactly like a Google
/// photo's credit does - see HiddenPlaceResponseItemDto.PhotoAttribution.
/// </summary>
public sealed record ReviewCoverPhoto(string PhotoUrl, string? Attribution);

public interface IReviewPhotoRepository
{
    Task<List<ReviewPhoto>> GetByReviewIdAsync(long reviewId);

    /// <summary>
    /// One cover photo per Google place, taken from the reviews our own users wrote about it.
    ///
    /// This exists because a genuinely obscure place - which is most of what a hidden-gem search
    /// returns - often has no Google photo at all, leaving the Explore Places card showing a
    /// placeholder even when somebody has been there and posted pictures. Those pictures are
    /// already in our own bucket and cost nothing to serve, so they are the obvious stand-in.
    ///
    /// Only ACTIVE reviews count: a review taken down by reports (status REMOVED) must not keep
    /// putting its photo on the map, and a deleted one has had its files removed already.
    ///
    /// Places with no usable review photo are absent from the dictionary rather than mapped to
    /// null, matching IPlacePhotoService.EnsurePhotosAsync.
    /// </summary>
    Task<Dictionary<string, ReviewCoverPhoto>> GetCoverPhotosByGooglePlaceIdsAsync(
        IReadOnlyCollection<string> googlePlaceIds);

    /// <summary>
    /// The same lookup for community places, keyed by <c>recommend_place_id</c> - the canonical
    /// place id a review stores, NOT the submission id the discovery API advertises as PlaceId.
    ///
    /// Second in line for a community place: the photos its recommender uploaded with the
    /// submission come first (recommended_places.photo_json), and this only covers the ones who
    /// submitted without any.
    /// </summary>
    Task<Dictionary<string, ReviewCoverPhoto>> GetCoverPhotosByRecommendPlaceIdsAsync(
        IReadOnlyCollection<string> recommendPlaceIds);

    Task AddAsync(ReviewPhoto photo);

    Task AddRangeAsync(List<ReviewPhoto> photos);

    Task DeleteAsync(ReviewPhoto photo);

    Task DeleteByReviewIdAsync(long reviewId);
}