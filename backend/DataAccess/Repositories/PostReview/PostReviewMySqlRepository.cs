using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;

namespace ExploreMy.Api.DataAccess.Repositories.PostReview;

public class PostReviewMySqlRepository : IPostReviewRepository
{
    private readonly MySqlDbContext _context;
    private readonly ILogger<PostReviewMySqlRepository> _logger;

    public PostReviewMySqlRepository(MySqlDbContext context, ILogger<PostReviewMySqlRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    // ---------------- Posts ----------------

    public async Task<List<Post>> GetFeedAsync(int currentUserId, PostFeedSort sort, int? minEngagement, int? maxEngagement, int page, int pageSize)
    {
        try
        {
            // Saved feed: only posts the current user saved, ordered by the
            // saved record's CreatedAt (newest save first). Queried directly
            // via a save-relationship filter (no per-post Saves.Any projection).
            if (sort == PostFeedSort.Saved)
            {
                var savedQuery = _context.Posts
                    .Where(p => p.Status == PostStatus.Active
                                && _context.UserSavedPosts.Any(s => s.UserId == currentUserId && s.PostId == p.PostId))
                    .OrderByDescending(p => _context.UserSavedPosts
                        .Where(s => s.UserId == currentUserId && s.PostId == p.PostId)
                        .Select(s => s.CreatedAt)
                        .FirstOrDefault())
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .Include(p => p.Author)
                    .Include(p => p.Images)
                    .Include(p => p.Reactions)
                    .Include(p => p.Comments)
                    .Include(p => p.Reports);

                var savedPosts = await savedQuery.ToListAsync();
                await HydrateTaggedPlacesAsync(savedPosts);
                return savedPosts;
            }

            IQueryable<Post> query = _context.Posts
                .Where(p => p.Status == PostStatus.Active)
                .Include(p => p.Author)
                .Include(p => p.Images)
                .Include(p => p.Reactions)
                .Include(p => p.Comments)
                .Include(p => p.Reports);

            // D2: popularity = number of likes + number of comments. When a
            // min/max engagement range is given, only posts whose engagement
            // falls inside the range are included; within the range posts are
            // ordered highest → lowest engagement.
            if (sort == PostFeedSort.Popularity)
            {
                query = query
                    .Where(p =>
                        (minEngagement == null
                         || p.Reactions.Count(r => r.Status == PostReactionStatus.Active)
                            + p.Comments.Count(c => c.Status == PostCommentStatus.Active) >= minEngagement)
                        && (maxEngagement == null
                            || p.Reactions.Count(r => r.Status == PostReactionStatus.Active)
                            + p.Comments.Count(c => c.Status == PostCommentStatus.Active) <= maxEngagement))
                    .OrderByDescending(p => p.Reactions.Count(r => r.Status == PostReactionStatus.Active)
                                            + p.Comments.Count(c => c.Status == PostCommentStatus.Active))
                    .ThenByDescending(p => p.CreatedAt);
            }
            else
            {
                query = query.OrderByDescending(p => p.CreatedAt);
            }

            var feedPosts = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();
            await HydrateTaggedPlacesAsync(feedPosts);
            return feedPosts;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading community post feed for user {UserId}.", currentUserId);
            throw;
        }
    }

    /// <summary>
    /// Posts the current user has an ACTIVE comment on (My Activity → Commented).
    /// </summary>
    public async Task<List<Post>> GetPostsCommentedByAsync(int userId, int page, int pageSize)
    {
        try
        {
            var commentedPosts = await _context.Posts
                .Where(p => p.Status == PostStatus.Active
                            && p.Comments.Any(c => c.AuthorId == userId && c.Status == PostCommentStatus.Active))
                .Include(p => p.Author)
                .Include(p => p.Images)
                .Include(p => p.Reactions)
                .Include(p => p.Comments)
                .Include(p => p.Reports)
                .OrderByDescending(p => p.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();
            await HydrateTaggedPlacesAsync(commentedPosts);
            return commentedPosts;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading posts commented on by user {UserId}.", userId);
            throw;
        }
    }

    /// <summary>
    /// Posts the current user has an ACTIVE report on (My Activity → Reported).
    /// </summary>
    public async Task<List<Post>> GetPostsReportedByAsync(int userId, int page, int pageSize)
    {
        try
        {
            var reportedPosts = await _context.Posts
                .Where(p => p.Status == PostStatus.Active
                            && p.Reports.Any(r => r.ReporterId == userId && r.Status == PostReportStatus.Active))
                .Include(p => p.Author)
                .Include(p => p.Images)
                .Include(p => p.Reactions)
                .Include(p => p.Comments)
                .Include(p => p.Reports)
                .OrderByDescending(p => p.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();
            await HydrateTaggedPlacesAsync(reportedPosts);
            return reportedPosts;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading posts reported by user {UserId}.", userId);
            throw;
        }
    }

    /// <summary>
    /// Full-text-ish search over active community posts (title, description,
    /// tagged place name/address, author name).
    /// </summary>
    public async Task<List<Post>> SearchPostsAsync(int currentUserId, string query, int page, int pageSize)
    {
        try
        {
            var trimmed = (query ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(trimmed))
            {
                return new List<Post>();
            }

            IQueryable<Post> queryable = _context.Posts
                .Where(p => p.Status == PostStatus.Active
                            && (p.Title != null && p.Title.Contains(trimmed)
                                || p.Description.Contains(trimmed)
                                || _context.Places.Any(pl => pl.PlaceId == p.TaggedPlaceId && pl.Name.Contains(trimmed))
                                || _context.Places.Any(pl => pl.PlaceId == p.TaggedPlaceId && pl.Address.Contains(trimmed))
                                || (p.Author != null && p.Author.Username.Contains(trimmed))))
                .Include(p => p.Author)
                .Include(p => p.Images)
                .Include(p => p.Reactions)
                .Include(p => p.Comments)
                .Include(p => p.Reports)
                .OrderByDescending(p => p.CreatedAt);

            var searchResults = await queryable
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();
            await HydrateTaggedPlacesAsync(searchResults);
            return searchResults;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while searching community posts for user {UserId} with query '{Query}'.", currentUserId, query);
            throw;
        }
    }

    public async Task<Post?> GetByIdAsync(string postId, int currentUserId)
    {
        try
        {
            var post = await _context.Posts
                .Include(p => p.Author)
                .Include(p => p.Images)
                .Include(p => p.Reactions)
                .Include(p => p.Comments).ThenInclude(c => c.Author)
                .Include(p => p.Reports)
                .Where(p => p.PostId == postId && p.Status == PostStatus.Active)
                .FirstOrDefaultAsync();
            if (post != null)
            {
                await HydrateTaggedPlacesAsync(new[] { post });
            }
            return post;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading post {PostId}.", postId);
            throw;
        }
    }

    public async Task<List<Post>> GetByAuthorAsync(int authorId)
    {
        try
        {
            var authorPosts = await _context.Posts
                .Where(p => p.AuthorId == authorId && p.Status == PostStatus.Active)
                .Include(p => p.Author)
                .Include(p => p.Images)
                .Include(p => p.Reactions)
                .Include(p => p.Comments)
                .OrderByDescending(p => p.CreatedAt)
                .ToListAsync();
            await HydrateTaggedPlacesAsync(authorPosts);
            return authorPosts;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading posts of author {AuthorId}.", authorId);
            throw;
        }
    }

    public async Task CreatePostAsync(Post post)
    {
        try
        {
            post.CreatedAt = DateTime.UtcNow;
            post.UpdatedAt = post.CreatedAt;
            _context.Posts.Add(post);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating community post.");
            throw;
        }
    }

    public async Task UpdatePostAsync(Post post)
    {
        try
        {
            post.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating community post {PostId}.", post.PostId);
            throw;
        }
    }

    public async Task<bool> PostExistsAsync(string postId)
    {
        try
        {
            return await _context.Posts.AnyAsync(p => p.PostId == postId && p.Status == PostStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking post {PostId}.", postId);
            throw;
        }
    }

    public async Task<bool> PlaceExistsAsync(string placeId)
    {
        try
        {
            return await _context.Places.AnyAsync(p => p.PlaceId == placeId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking place {PlaceId}.", placeId);
            throw;
        }
    }

    public async Task<int> IncrementViewsAsync(string postId)
    {
        try
        {
            var post = await _context.Posts.FirstOrDefaultAsync(p => p.PostId == postId);
            if (post is null)
            {
                return 0;
            }
            post.ViewsCount++;
            // Do not touch UpdatedAt — a view is not an edit.
            await _context.SaveChangesAsync();
            return post.ViewsCount;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while incrementing views of post {PostId}.", postId);
            throw;
        }
    }

    // ---------------- Comments ----------------

    public async Task<List<PostComment>> GetCommentsByPostAsync(string postId)
    {
        try
        {
            return await _context.PostComments
                .Where(c => c.PostId == postId && c.Status == PostCommentStatus.Active)
                .Include(c => c.Author)
                .OrderBy(c => c.CreatedAt)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading comments for post {PostId}.", postId);
            throw;
        }
    }

    public async Task<PostComment?> GetCommentByIdAsync(string commentId)
    {
        try
        {
            return await _context.PostComments
                .Include(c => c.Author)
                .FirstOrDefaultAsync(c => c.CommentId == commentId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading comment {CommentId}.", commentId);
            throw;
        }
    }

    public async Task<List<PostComment>> GetCommentsByAuthorAsync(int authorId)
    {
        try
        {
            return await _context.PostComments
                .Where(c => c.AuthorId == authorId && c.Status == PostCommentStatus.Active)
                .Include(c => c.Author)
                .Include(c => c.Post)
                .OrderByDescending(c => c.CreatedAt)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading comments of author {AuthorId}.", authorId);
            throw;
        }
    }

    public async Task CreateCommentAsync(PostComment comment)
    {
        try
        {
            comment.CreatedAt = DateTime.UtcNow;
            comment.UpdatedAt = comment.CreatedAt;
            _context.PostComments.Add(comment);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating comment.");
            throw;
        }
    }

    public async Task UpdateCommentAsync(PostComment comment)
    {
        try
        {
            comment.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating comment {CommentId}.", comment.CommentId);
            throw;
        }
    }

    public async Task<bool> CommentExistsAsync(string commentId)
    {
        try
        {
            return await _context.PostComments.AnyAsync(c => c.CommentId == commentId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking comment {CommentId}.", commentId);
            throw;
        }
    }

    // ---------------- Reactions ----------------

    public async Task<PostReaction?> GetActiveReactionAsync(string postId, int userId)
    {
        try
        {
            return await _context.PostReactions
                .FirstOrDefaultAsync(r => r.PostId == postId
                                          && r.UserId == userId
                                          && r.Status == PostReactionStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading active reaction of user {UserId} on post {PostId}.", userId, postId);
            throw;
        }
    }

    public async Task<PostReaction?> GetAnyReactionAsync(string postId, int userId)
    {
        try
        {
            return await _context.PostReactions
                .FirstOrDefaultAsync(r => r.PostId == postId && r.UserId == userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading reaction of user {UserId} on post {PostId}.", userId, postId);
            throw;
        }
    }

    public async Task CreateReactionAsync(PostReaction reaction)
    {
        try
        {
            reaction.CreatedAt = DateTime.UtcNow;
            reaction.UpdatedAt = reaction.CreatedAt;
            _context.PostReactions.Add(reaction);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating reaction.");
            throw;
        }
    }

    public async Task UpdateReactionAsync(PostReaction reaction)
    {
        try
        {
            reaction.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating reaction {ReactionId}.", reaction.ReactionId);
            throw;
        }
    }

    public async Task<int> GetActiveReactionCountAsync(string postId)
    {
        try
        {
            return await _context.PostReactions
                .CountAsync(r => r.PostId == postId && r.Status == PostReactionStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while counting reactions for post {PostId}.", postId);
            throw;
        }
    }

    // ---------------- Reports ----------------

    public async Task CreateReportAsync(PostReport report)
    {
        try
        {
            report.CreatedAt = DateTime.UtcNow;
            _context.PostReports.Add(report);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating report.");
            throw;
        }
    }

    public async Task<List<PostReport>> GetReportsByReporterAsync(int reporterId)
    {
        try
        {
            var reports = await _context.PostReports
                .Where(r => r.ReporterId == reporterId)
                .Include(r => r.Post).ThenInclude(p => p!.Author)
                .Include(r => r.Post).ThenInclude(p => p!.Images)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();
            foreach (var report in reports)
            {
                await HydrateReportPostTaggedPlaceAsync(report);
            }
            return reports;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading reports of reporter {ReporterId}.", reporterId);
            throw;
        }
    }

    public async Task<PostReport?> GetReportByIdAsync(string reportId)
    {
        try
        {
            var report = await _context.PostReports
                .Include(r => r.Post).ThenInclude(p => p!.Author)
                .Include(r => r.Post).ThenInclude(p => p!.Images)
                .FirstOrDefaultAsync(r => r.ReportId == reportId);
            await HydrateReportPostTaggedPlaceAsync(report);
            return report;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading report {ReportId}.", reportId);
            throw;
        }
    }

    public async Task UpdateReportAsync(PostReport report)
    {
        try
        {
            _context.PostReports.Update(report);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating report {ReportId}.", report.ReportId);
            throw;
        }
    }

    public async Task<int> GetActiveReportCountAsync(string postId)
    {
        try
        {
            return await _context.PostReports
                .CountAsync(r => r.PostId == postId && r.Status == PostReportStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while counting reports for post {PostId}.", postId);
            throw;
        }
    }

    public async Task<bool> HasActiveReportAsync(string postId, int reporterId)
    {
        try
        {
            return await _context.PostReports.AnyAsync(r =>
                r.PostId == postId && r.ReporterId == reporterId && r.Status == PostReportStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking report on post {PostId} by user {ReporterId}.", postId, reporterId);
            throw;
        }
    }

    public async Task<PostReport?> GetActiveReportAsync(string postId, int reporterId)
    {
        try
        {
            return await _context.PostReports.FirstOrDefaultAsync(r =>
                r.PostId == postId && r.ReporterId == reporterId && r.Status == PostReportStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading active report on post {PostId} by user {ReporterId}.", postId, reporterId);
            throw;
        }
    }

    // ---------------- Saved posts ----------------

    public async Task CreateSavedPostAsync(UserSavedPost savedPost)
    {
        try
        {
            savedPost.CreatedAt = DateTime.UtcNow;
            _context.UserSavedPosts.Add(savedPost);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while saving post {PostId} for user {UserId}.", savedPost.PostId, savedPost.UserId);
            throw;
        }
    }

    public async Task DeleteSavedPostAsync(string postId, int userId)
    {
        try
        {
            var saved = await _context.UserSavedPosts
                .FirstOrDefaultAsync(s => s.PostId == postId && s.UserId == userId);
            if (saved != null)
            {
                _context.UserSavedPosts.Remove(saved);
                await _context.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while unsaving post {PostId} for user {UserId}.", postId, userId);
            throw;
        }
    }

    public async Task<bool> IsPostSavedAsync(string postId, int userId)
    {
        try
        {
            return await _context.UserSavedPosts.AnyAsync(s => s.PostId == postId && s.UserId == userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking saved status of post {PostId} for user {UserId}.", postId, userId);
            throw;
        }
    }

    public async Task<HashSet<string>> GetSavedPostIdsAsync(int userId)
    {
        try
        {
            var ids = await _context.UserSavedPosts
                .Where(s => s.UserId == userId)
                .Select(s => s.PostId)
                .ToListAsync();
            return new HashSet<string>(ids);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading saved post ids for user {UserId}.", userId);
            throw;
        }
    }

    public async Task<Post?> GetPostForSaveValidationAsync(string postId)
    {
        try
        {
            return await _context.Posts
                .Where(p => p.Status == PostStatus.Active)
                .FirstOrDefaultAsync(p => p.PostId == postId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while validating post {PostId} for save.", postId);
            throw;
        }
    }

    // ---------------- Tagged place hydration (Priority 3) ----------------
    //
    // community_posts.tagged_place_id is a reference-only field (no FK). EF
    // loads the scalar column; we hydrate the runtime TaggedPlace reference
    // from the places table so the DTO mapper can still surface the tagged
    // place name/address without any EF relationship.

    private async Task HydrateTaggedPlacesAsync(IEnumerable<Post> posts)
    {
        var ids = posts
            .Where(p => !string.IsNullOrEmpty(p.TaggedPlaceId))
            .Select(p => p.TaggedPlaceId)
            .Distinct()
            .ToList();
        if (ids.Count == 0)
        {
            return;
        }

        var places = await _context.Places
            .Where(pl => ids.Contains(pl.PlaceId))
            .ToDictionaryAsync(pl => pl.PlaceId);
        foreach (var post in posts)
        {
            if (places.TryGetValue(post.TaggedPlaceId, out var place))
            {
                post.TaggedPlace = place;
            }
        }
    }

    private async Task HydrateReportPostTaggedPlaceAsync(PostReport? report)
    {
        if (report?.Post != null && !string.IsNullOrEmpty(report.Post.TaggedPlaceId))
        {
            await HydrateTaggedPlacesAsync(new[] { report.Post });
        }
    }
}
