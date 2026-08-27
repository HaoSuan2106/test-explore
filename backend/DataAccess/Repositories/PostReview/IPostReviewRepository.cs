using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.DataAccess.Repositories.PostReview;

/// <summary>Sort / filter modes for the community post feed.</summary>
public enum PostFeedSort
{
    Newest,
    Popularity,
    Saved,
}

public interface IPostReviewRepository
{
    // ---- Posts ----
    /// <summary>
    /// Loads the discover feed. [minEngagement]/[maxEngagement] optionally
    /// restrict the popularity range (likes + comments) when sort is Popularity.
    /// </summary>
    Task<List<Post>> GetFeedAsync(int currentUserId, PostFeedSort sort, int? minEngagement, int? maxEngagement, int page, int pageSize);
    Task<List<Post>> GetPostsCommentedByAsync(int userId, int page, int pageSize);
    Task<List<Post>> GetPostsReportedByAsync(int userId, int page, int pageSize);
    Task<Post?> GetByIdAsync(string postId, int currentUserId);
    Task<List<Post>> SearchPostsAsync(int currentUserId, string query, int page, int pageSize);
    Task<List<Post>> GetByAuthorAsync(int authorId);
    Task CreatePostAsync(Post post);
    Task UpdatePostAsync(Post post);
    Task<bool> PostExistsAsync(string postId);
    Task<bool> PlaceExistsAsync(string placeId);

    /// <summary>Increments the view counter of a post without touching UpdatedAt.</summary>
    Task<int> IncrementViewsAsync(string postId);

    // ---- Comments ----
    Task<List<PostComment>> GetCommentsByPostAsync(string postId);
    Task<PostComment?> GetCommentByIdAsync(string commentId);
    Task<List<PostComment>> GetCommentsByAuthorAsync(int authorId);
    Task CreateCommentAsync(PostComment comment);
    Task UpdateCommentAsync(PostComment comment);
    Task<bool> CommentExistsAsync(string commentId);

    // ---- Reactions ----
    Task<PostReaction?> GetActiveReactionAsync(string postId, int userId);
    Task<PostReaction?> GetAnyReactionAsync(string postId, int userId);
    Task CreateReactionAsync(PostReaction reaction);
    Task UpdateReactionAsync(PostReaction reaction);
    Task<int> GetActiveReactionCountAsync(string postId);

    // ---- Reports ----
    Task CreateReportAsync(PostReport report);
    Task<List<PostReport>> GetReportsByReporterAsync(int reporterId);
    Task<int> GetActiveReportCountAsync(string postId);
    Task<bool> HasActiveReportAsync(string postId, int reporterId);
    Task<PostReport?> GetActiveReportAsync(string postId, int reporterId);

    // ---- Saved posts ----
    Task CreateSavedPostAsync(UserSavedPost savedPost);
    Task DeleteSavedPostAsync(string postId, int userId);
    Task<bool> IsPostSavedAsync(string postId, int userId);

    /// <summary>
    /// Returns the post ids of the posts the user has saved (used for the
    /// Saved feed sort and for populating IsSavedByCurrentUser on summaries
    /// without loading every save relationship of every post).
    /// </summary>
    Task<HashSet<string>> GetSavedPostIdsAsync(int userId);

    /// <summary>Loads a post to validate it for save/unsave operations.</summary>
    Task<Post?> GetPostForSaveValidationAsync(string postId);

    // ---- Eligible attractions ----
    Task<List<Place>> GetEligibleAttractionsAsync(int userId);
}