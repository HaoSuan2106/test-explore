using ExploreMy.Api.Application.FootTracker.Facade;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using Microsoft.Extensions.Options;
using ExploreMy.Api.DataAccess.Repositories.PostReview;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.FootTracker;
using ExploreMy.Api.DTOs.PostReview;

namespace ExploreMy.Api.Application.PostReview.ManagePost;

public class ManagePostService : IManagePostService
{
    private readonly IPostReviewRepository _repository;
    private readonly IStorageClient _storageClient;
    private readonly ILogger<ManagePostService> _logger;
    private readonly IFootTrackerService _footTrackerService;
    private readonly SupabaseSettings _supabase;

    public ManagePostService(
        IPostReviewRepository repository,
        IStorageClient storageClient,
        ILogger<ManagePostService> logger,
        IFootTrackerService footTrackerService,
        IOptions<SupabaseSettings> supabase)
    {
        _repository = repository;
        _storageClient = storageClient;
        _logger = logger;
        _footTrackerService = footTrackerService;
        _supabase = supabase.Value;
    }

    /// <summary>
    /// Feed with the frozen two-section contract:
    ///   MY ACTIVITY:  category=myActivity&amp;type=posted|commented|reported
    ///   DISCOVER:     category=discover&amp;sort=newest|popularity|saved
    ///                 + optional min/max engagement range (likes+comments).
    /// </summary>
    public async Task<List<PostSummaryDto>> GetFeedAsync(int currentUserId, string? category, string? type, string? sort, int? minEngagement, int? maxEngagement, int page, int pageSize)
    {
        // My Activity filters: posts authored / commented / reported by the
        // current user. The frontend requests the appropriate filtered feed
        // (no separate My Activity endpoint is required).
        if (string.Equals(category, "myActivity", StringComparison.OrdinalIgnoreCase))
        {
            List<Post> posts = type?.ToLowerInvariant() switch
            {
                "posted" => await _repository.GetByAuthorAsync(currentUserId),
                "commented" => await _repository.GetPostsCommentedByAsync(currentUserId, page, pageSize),
                "reported" => await _repository.GetPostsReportedByAsync(currentUserId, page, pageSize),
                _ => new List<Post>(),
            };
            return await ToSummariesAsync(posts, currentUserId);
        }

        var sortMode = sort?.ToLowerInvariant() switch
        {
            "popularity" or "popular" => PostFeedSort.Popularity,
            "saved" => PostFeedSort.Saved,
            _ => PostFeedSort.Newest,
        };

        var posts2 = await _repository.GetFeedAsync(currentUserId, sortMode, minEngagement, maxEngagement, page, pageSize);
        return await ToSummariesAsync(posts2, currentUserId);
    }

    public async Task<List<PostSummaryDto>> SearchPostsAsync(int currentUserId, string query, int page, int pageSize)
    {
        var posts = await _repository.SearchPostsAsync(currentUserId, query, page, pageSize);
        return await ToSummariesAsync(posts, currentUserId);
    }

    public async Task<PostDetailsDto> GetPostDetailsAsync(int currentUserId, string postId)
    {
        var post = await _repository.GetByIdAsync(postId, currentUserId)
                   ?? throw new NotFoundException("Post not found.");

        // L-08: a detail view counts as a view (does not alter UpdatedAt).
        post.ViewsCount = await _repository.IncrementViewsAsync(postId);

        var comments = (await _repository.GetCommentsByPostAsync(postId))
            .Select(PostDtoMapper.ToComment)
            .ToList();

        var savedPostIds = await _repository.GetSavedPostIdsAsync(currentUserId);
        return PostDtoMapper.ToDetails(post, currentUserId, comments, savedPostIds);
    }

    public async Task<List<PostSummaryDto>> GetMyPostsAsync(int currentUserId)
    {
        var posts = await _repository.GetByAuthorAsync(currentUserId);
        return await ToSummariesAsync(posts, currentUserId);
    }

    public async Task<List<PostSummaryDto>> GetMyLikedPostsAsync(int currentUserId, int page, int pageSize)
    {
        var posts = await _repository.GetPostsLikedByAsync(currentUserId, page, pageSize);
        return await ToSummariesAsync(posts, currentUserId);
    }

    public async Task<CreatePostResponseDto> CreatePostAsync(int currentUserId, CreatePostRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.Description))
        {
            throw new ValidationException("Post description cannot be blank.");
        }

        if (request.Description.Length > PostLimits.MaxDescriptionLength)
        {
            throw new ValidationException($"Post description must not exceed {PostLimits.MaxDescriptionLength} characters.");
        }

        // F13: Post title is compulsory (business decision H-4).
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            throw new ValidationException("Post title is required.");
        }

        if (request.Title.Length > PostLimits.MaxTitleLength)
        {
            throw new ValidationException($"Post title must not exceed {PostLimits.MaxTitleLength} characters.");
        }

        if (request.Images.Count > PostImageLimits.MaxImages)
        {
            throw new ValidationException($"A post can have at most {PostImageLimits.MaxImages} images.");
        }

        // F12: the tagged place must be one the user has actually explored
        // (real FootTracker visits), not merely any existing place. The
        // Recommendation module reads that data through IFootTrackerService
        // (GetVisitsAsync → List<VisitLogDto>) instead of querying the DB.
        var visits = await _footTrackerService.GetVisitsAsync(currentUserId);
        if (!visits.Any(v => v.PlaceId != null && v.PlaceId == request.TaggedPlaceId))
        {
            throw new ValidationException("The tagged place is not in your explored places. Please select from your eligible attractions.");
        }

        var post = new Post
        {
            AuthorId = currentUserId,
            TaggedPlaceId = request.TaggedPlaceId,
            Title = request.Title.Trim(),
            Description = request.Description.Trim(),
            Status = PostStatus.Active,
            Images = request.Images
                .OrderBy(i => i.DisplayOrder)
                .Select(i => new PostImage
                {
                    ImageUrl = i.ImageUrl,
                    DisplayOrder = i.DisplayOrder,
                    CreatedAt = DateTime.UtcNow,
                })
                .ToList(),
        };

        await _repository.CreatePostAsync(post);

        _logger.LogInformation(
            "[POST-DTO] User {UserId} created community post {PostId} with {ImageCount} image(s): ["
            + string.Join(" | ", post.Images.Select(i => $"[{i.DisplayOrder}] {i.ImageUrl}")) + "]",
            currentUserId, post.PostId, post.Images.Count);
        _logger.LogInformation("User {UserId} created community post {PostId}.", currentUserId, post.PostId);
        return new CreatePostResponseDto
        {
            PostId = post.PostId,
            Message = "Post created successfully.",
        };
    }

    public async Task<UpdatePostResponseDto> UpdatePostAsync(int currentUserId, string postId, UpdatePostRequestDto request)
    {
        var post = await _repository.GetByIdAsync(postId, currentUserId)
                   ?? throw new NotFoundException("Post not found.");

        if (post.AuthorId != currentUserId)
        {
            throw new ForbiddenException("You can only modify your own posts.");
        }

        if (post.Status != PostStatus.Active)
        {
            throw new ForbiddenException("This post can no longer be edited.");
        }

        if (string.IsNullOrWhiteSpace(request.Description))
        {
            throw new ValidationException("Post description cannot be blank.");
        }

        if (request.Description.Length > PostLimits.MaxDescriptionLength)
        {
            throw new ValidationException($"Post description must not exceed {PostLimits.MaxDescriptionLength} characters.");
        }

        if (request.Images.Count > PostImageLimits.MaxImages)
        {
            throw new ValidationException($"A post can have at most {PostImageLimits.MaxImages} images.");
        }

        // F13: Post title is compulsory (business decision H-4).
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            throw new ValidationException("Post title is required.");
        }

        if (request.Title.Length > PostLimits.MaxTitleLength)
        {
            throw new ValidationException($"Post title must not exceed {PostLimits.MaxTitleLength} characters.");
        }

        post.Title = request.Title.Trim();
        post.Description = request.Description.Trim();

        // Replace image collection with the submitted set.
        post.Images.Clear();
        foreach (var image in request.Images.OrderBy(i => i.DisplayOrder))
        {
            post.Images.Add(new PostImage
            {
                ImageUrl = image.ImageUrl,
                DisplayOrder = image.DisplayOrder,
                CreatedAt = DateTime.UtcNow,
            });
        }

        await _repository.UpdatePostAsync(post);

        _logger.LogInformation("User {UserId} updated community post {PostId}.", currentUserId, postId);
        var updated = await _repository.GetByIdAsync(postId, currentUserId);
        return new UpdatePostResponseDto
        {
            Post = updated is null ? null! : PostDtoMapper.ToSummary(updated, currentUserId),
            Message = "Post updated successfully.",
        };
    }

    public async Task<DeletePostResponseDto> DeletePostAsync(int currentUserId, string postId)
    {
        var post = await _repository.GetByIdAsync(postId, currentUserId)
                   ?? throw new NotFoundException("Post not found.");

        if (post.AuthorId != currentUserId)
        {
            throw new ForbiddenException("You can only delete your own posts.");
        }

        post.Status = PostStatus.Deleted;
        await _repository.UpdatePostAsync(post);

        _logger.LogInformation("User {UserId} deleted community post {PostId}.", currentUserId, postId);
        return new DeletePostResponseDto
        {
            PostId = postId,
            Message = "Post deleted successfully.",
        };
    }

    /// <summary>
    /// Builds the list of visited attractions (recommendation candidates) from
    /// the user's real FootTracker visit data. The Recommendation module
    /// consumes List&lt;VisitLogDto&gt; produced by IFootTrackerService and
    /// owns the mapping/rules; it never touches foot_tracker_log directly.
    /// </summary>
    public async Task<List<VisitedAttractionDto>> GetVisitedAttractionsAsync(int currentUserId)
    {
        var visits = await _footTrackerService.GetVisitsAsync(currentUserId);
        return visits
            .Where(v => !string.IsNullOrEmpty(v.PlaceId))
            .GroupBy(v => v.PlaceId!)
            .Select(g => g.OrderByDescending(v => v.EndedAt).First())
            .OrderBy(v => v.Title)
            .Select(PostDtoMapper.ToVisitedAttraction)
            .ToList();
    }

    public async Task<bool> HasVisitedAttractionsAsync(int currentUserId)
    {
        var visits = await _footTrackerService.GetVisitsAsync(currentUserId);
        return visits.Any(v => !string.IsNullOrEmpty(v.PlaceId));
    }

    /// <summary>
    /// Uploads a post image to storage and returns its public URL (REQ501_4/5).
    /// Format and size are validated by the controller before this call.
    /// Uploads into the dedicated <c>post-images</c> bucket. Because images are
    /// selected before the post is created (draft phase), the post id does not
    /// exist yet, so the object path is scoped per user with a unique file name.
    /// </summary>
    public async Task<string> UploadPostImageAsync(int currentUserId, Stream fileStream, string fileName, string contentType)
    {
        var bucket = _supabase.PostImageBucket;
        var extension = Path.GetExtension(fileName);
        var path = $"posts/{currentUserId}/{Guid.NewGuid()}{extension}";
        var url = await _storageClient.UploadToBucketAsync(bucket, path, fileStream, contentType);
        _logger.LogInformation("User {UserId} uploaded post image {Path}.", currentUserId, path);
        return url;
    }

    // ---------------- Saved posts ----------------

    public async Task<SavePostResponseDto> SavePostAsync(int currentUserId, string postId)
    {
        var post = await _repository.GetPostForSaveValidationAsync(postId)
                   ?? throw new NotFoundException("Post not found or no longer available.");

        if (post.AuthorId == currentUserId)
        {
            throw new ForbiddenException("You cannot save your own post.");
        }

        // Check reported-post restriction: user with active report cannot save
        if (await _repository.HasActiveReportAsync(postId, currentUserId))
        {
            throw new ForbiddenException("You cannot save a post you have reported.");
        }

        if (await _repository.IsPostSavedAsync(postId, currentUserId))
        {
            // Already saved — idempotent success (no duplicate per UNIQUE constraint).
            return new SavePostResponseDto { PostId = postId, IsSaved = true, Message = "Post already saved." };
        }

        var saved = new UserSavedPost
        {
            PostId = postId,
            UserId = currentUserId,
        };

        await _repository.CreateSavedPostAsync(saved);

        _logger.LogInformation("User {UserId} saved post {PostId}.", currentUserId, postId);
        return new SavePostResponseDto { PostId = postId, IsSaved = true, Message = "Post saved successfully." };
    }

    public async Task<SavePostResponseDto> UnsavePostAsync(int currentUserId, string postId)
    {
        var post = await _repository.GetPostForSaveValidationAsync(postId);
        // Silently succeed if the post is gone (idempotent unsave).
        // But still check if it was saved by this user.
        if (!await _repository.IsPostSavedAsync(postId, currentUserId))
        {
            return new SavePostResponseDto { PostId = postId, IsSaved = false, Message = "Post was not saved." };
        }

        await _repository.DeleteSavedPostAsync(postId, currentUserId);

        _logger.LogInformation("User {UserId} unsaved post {PostId}.", currentUserId, postId);
        return new SavePostResponseDto { PostId = postId, IsSaved = false, Message = "Post unsaved successfully." };
    }

    /// <summary>
    /// Loads saved post IDs for the current user once and passes them to the
    /// mapper, avoiding an N+1 pattern of checking Saves per post.
    /// </summary>
    private async Task<List<PostSummaryDto>> ToSummariesAsync(List<Post> posts, int currentUserId)
    {
        var savedPostIds = await _repository.GetSavedPostIdsAsync(currentUserId);
        return posts.Select(p => PostDtoMapper.ToSummary(p, currentUserId, savedPostIds)).ToList();
    }
}