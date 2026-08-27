using System.Security.Claims;
using ExploreMy.Api.Application.PostReview.Facade;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DTOs.PostReview;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ExploreMy.Api.Controllers.PostReview;

[Route("api/posts")]
[ApiController]
[Authorize]
public class PostController : ControllerBase
{
    private readonly IPostReviewService _postReviewService;
    private readonly ILogger<PostController> _logger;

    public PostController(IPostReviewService postReviewService, ILogger<PostController> logger)
    {
        _postReviewService = postReviewService;
        _logger = logger;
    }

    private static readonly HashSet<string> AllowedPostImageContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg", "image/png",
    };

    private const long PostImageUploadMaxSizeBytes = 5 * 1024 * 1024;

    private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    // ============================================================
    // Posts
    // ============================================================

    /// <summary>
    /// Retrieve the community post feed (frozen two-section contract):
    ///   MY ACTIVITY — category=myActivity&amp;type=posted|commented|reported
    ///   DISCOVER — category=discover&amp;sort=newest|popularity|saved,
    ///               with optional min/max engagement range (likes+comments)
    ///               for the popularity sort.
    /// The legacy single `filter` parameter (popular|saved) is still accepted
    /// for backward compatibility with earlier clients.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetFeed(
        [FromQuery] string? category,
        [FromQuery] string? type,
        [FromQuery] string? sort,
        [FromQuery] int? min,
        [FromQuery] int? max,
        [FromQuery] string? filter,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1 || pageSize < 1)
            return BadRequest(new { message = "Page and pageSize must be at least 1." });

        // Legacy `filter` mapping (popular|saved) → discover sort.
        if (string.IsNullOrWhiteSpace(category) && string.IsNullOrWhiteSpace(sort))
        {
            category = "discover";
            sort = filter?.ToLowerInvariant() switch
            {
                "popular" or "popularity" => "popularity",
                "saved" => "saved",
                _ => "newest",
            };
        }

        try
        {
            var posts = await _postReviewService.GetFeedAsync(CurrentUserId, category, type, sort, min, max, page, pageSize);
            return Ok(posts);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching post feed for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Search active community posts by title, description, tagged
    /// place or author name (hidden posts are excluded).</summary>
    [HttpGet("search")]
    public async Task<IActionResult> SearchPosts([FromQuery] string q, [FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        if (page < 1 || pageSize < 1)
            return BadRequest(new { message = "Page and pageSize must be at least 1." });

        try
        {
            var results = await _postReviewService.SearchPostsAsync(CurrentUserId, q, page, pageSize);
            return Ok(results);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error searching posts for user {UserId} with query '{Query}'.", CurrentUserId, q);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Retrieve details of a single community post.</summary>
    [HttpGet("{postId}")]
    public async Task<IActionResult> GetPostDetails(string postId)
    {
        try
        {
            var details = await _postReviewService.GetPostDetailsAsync(CurrentUserId, postId);
            return Ok(details);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching post {PostId} for user {UserId}.", postId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Retrieve the authenticated user's own posts (My Activity → My Posts).</summary>
    [HttpGet("mine")]
    public async Task<IActionResult> GetMyPosts()
    {
        try
        {
            var posts = await _postReviewService.GetMyPostsAsync(CurrentUserId);
            return Ok(posts);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching own posts for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Create a new community post.</summary>
    [HttpPost]
    public async Task<IActionResult> CreatePost([FromBody] CreatePostRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid post data.", errors = ModelState });
        }

        try
        {
            var result = await _postReviewService.CreatePostAsync(CurrentUserId, request);
            return CreatedAtAction(nameof(GetPostDetails), new { postId = result.PostId }, result);
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error creating post for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Update the authenticated user's own post.</summary>
    [HttpPut("{postId}")]
    public async Task<IActionResult> UpdatePost(string postId, [FromBody] UpdatePostRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid post data.", errors = ModelState });
        }

        try
        {
            var result = await _postReviewService.UpdatePostAsync(CurrentUserId, postId, request);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error updating post {PostId} for user {UserId}.", postId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Soft-delete the authenticated user's own post.</summary>
    [HttpDelete("{postId}")]
    public async Task<IActionResult> DeletePost(string postId)
    {
        try
        {
            var result = await _postReviewService.DeletePostAsync(CurrentUserId, postId);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error deleting post {PostId} for user {UserId}.", postId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Eligible attractions from the authenticated user's exploration history.</summary>
    [HttpGet("eligible-attractions")]
    public async Task<IActionResult> GetEligibleAttractions()
    {
        try
        {
            var attractions = await _postReviewService.GetEligibleAttractionsAsync(CurrentUserId);
            return Ok(attractions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching eligible attractions for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Whether the authenticated user has any eligible attractions.</summary>
    [HttpGet("eligible-attractions/has")]
    public async Task<IActionResult> HasEligibleAttractions()
    {
        try
        {
            var has = await _postReviewService.HasEligibleAttractionsAsync(CurrentUserId);
            return Ok(new { hasEligibleAttractions = has });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error checking eligible attractions for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>
    /// Upload a post image (JPEG/PNG, max 5 MB). Returns the public URL for
    /// later use in create/update post requests (REQ501_4/5).
    /// </summary>
    [HttpPost("images/upload")]
    [RequestSizeLimit(PostImageUploadMaxSizeBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = PostImageUploadMaxSizeBytes)]
    public async Task<IActionResult> UploadPostImage(IFormFile? file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "No image was uploaded." });
        }

        if (file.Length > PostImageUploadMaxSizeBytes)
        {
            return BadRequest(new { message = "Image exceeds the 5 MB size limit." });
        }

        if (!AllowedPostImageContentTypes.Contains(file.ContentType))
        {
            return BadRequest(new { message = "Unsupported image type. Allowed: JPEG, PNG." });
        }

        try
        {
            await using var stream = file.OpenReadStream();
            var url = await _postReviewService.UploadPostImageAsync(CurrentUserId, stream, file.FileName, file.ContentType);
            return Ok(new { imageUrl = url });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error uploading post image for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Comments
    // ============================================================

    /// <summary>Retrieve comments for a community post.</summary>
    [HttpGet("{postId}/comments")]
    public async Task<IActionResult> GetComments(string postId)
    {
        try
        {
            var comments = await _postReviewService.GetCommentsAsync(postId);
            return Ok(comments);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching comments for post {PostId}.", postId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Create a comment on a community post.</summary>
    [HttpPost("{postId}/comments")]
    public async Task<IActionResult> CreateComment(string postId, [FromBody] CreateCommentRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid comment data.", errors = ModelState });
        }

        try
        {
            var result = await _postReviewService.CreateCommentAsync(CurrentUserId, postId, request);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error creating comment on post {PostId} for user {UserId}.", postId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Retrieve the authenticated user's own comments (My Activity → My Comments).</summary>
    [HttpGet("comments/mine")]
    public async Task<IActionResult> GetMyComments()
    {
        try
        {
            var comments = await _postReviewService.GetMyCommentsAsync(CurrentUserId);
            return Ok(comments);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching own comments for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Comments - D-03 guards
    // ============================================================

    /// <summary>
    /// D-03: a missing comment id must not fall through to the generic post
    /// routes. Without this literal route, "PUT /api/posts/comments" would
    /// bind "comments" to the {postId} parameter of UpdatePost and fail with
    /// a misleading post-validation error ("Invalid post data."). The literal
    /// "comments" segment takes precedence over the "{postId}" parameter.
    /// </summary>
    [HttpPut("comments")]
    public IActionResult UpdateCommentMissingId()
        => BadRequest(new { message = "Comment ID is required to update a comment." });

    /// <summary>
    /// D-03: same protection for comment deletion - "DELETE /api/posts/comments"
    /// must never reach DeletePost's {postId} route.
    /// </summary>
    [HttpDelete("comments")]
    public IActionResult DeleteCommentMissingId()
        => BadRequest(new { message = "Comment ID is required to delete a comment." });

    /// <summary>Update the authenticated user's own comment.</summary>
    [HttpPut("comments/{commentId}")]
    public async Task<IActionResult> UpdateComment(string commentId, [FromBody] UpdateCommentRequestDto request)
    {
        // D-03: never let an empty/whitespace comment id reach the service
        // or fall through to the post-update route.
        if (string.IsNullOrWhiteSpace(commentId))
        {
            return BadRequest(new { message = "Comment ID is required to update a comment." });
        }

        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid comment data.", errors = ModelState });
        }

        try
        {
            var result = await _postReviewService.UpdateCommentAsync(CurrentUserId, commentId, request);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error updating comment {CommentId} for user {UserId}.", commentId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Soft-delete the authenticated user's own comment.</summary>
    [HttpDelete("comments/{commentId}")]
    public async Task<IActionResult> DeleteComment(string commentId)
    {
        // D-03: guard against an empty/whitespace comment id so it never
        // falls through to the post-delete route.
        if (string.IsNullOrWhiteSpace(commentId))
        {
            return BadRequest(new { message = "Comment ID is required to delete a comment." });
        }

        try
        {
            var result = await _postReviewService.DeleteCommentAsync(CurrentUserId, commentId);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error deleting comment {CommentId} for user {UserId}.", commentId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Reactions
    // ============================================================

    /// <summary>Toggle the Love reaction on a community post; returns the updated count.</summary>
    [HttpPost("{postId}/reactions")]
    public async Task<IActionResult> ToggleReaction(string postId, [FromBody] ToggleReactionRequestDto request)
    {
        try
        {
            var result = await _postReviewService.ToggleReactionAsync(CurrentUserId, postId, request);
            return Ok(result);
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error toggling reaction on post {PostId} for user {UserId}.", postId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Reports
    // ============================================================

    /// <summary>Predefined report reasons (REQ501_13).</summary>
    [HttpGet("report-reasons")]
    public IActionResult GetReportReasons()
    {
        return Ok(new { reasons = _postReviewService.GetReportReasons() });
    }

    /// <summary>Submit a report against a community post.</summary>
    [HttpPost("{postId}/reports")]
    public async Task<IActionResult> CreateReport(string postId, [FromBody] CreateReportRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid report data.", errors = ModelState });
        }

        try
        {
            var result = await _postReviewService.CreateReportAsync(CurrentUserId, postId, request);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error reporting post {PostId} for user {UserId}.", postId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Retrieve the authenticated user's reports (My Activity → Reported Posts).</summary>
    [HttpGet("reports/mine")]
    public async Task<IActionResult> GetMyReports()
    {
        try
        {
            var reports = await _postReviewService.GetMyReportsAsync(CurrentUserId);
            return Ok(reports);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching own reports for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Saved posts
    // ============================================================

    /// <summary>Save a community post for the authenticated user.</summary>
    [HttpPost("{postId}/save")]
    public async Task<IActionResult> SavePost(string postId)
    {
        try
        {
            var result = await _postReviewService.SavePostAsync(CurrentUserId, postId);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error saving post {PostId} for user {UserId}.", postId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Unsave a community post for the authenticated user.</summary>
    [HttpDelete("{postId}/save")]
    public async Task<IActionResult> UnsavePost(string postId)
    {
        try
        {
            var result = await _postReviewService.UnsavePostAsync(CurrentUserId, postId);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error unsaving post {PostId} for user {UserId}.", postId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Retrieve the authenticated user's saved posts (Saved feed filter).</summary>
    [HttpGet("saved")]
    public async Task<IActionResult> GetSavedPosts([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        if (page < 1 || pageSize < 1)
            return BadRequest(new { message = "Page and pageSize must be at least 1." });

        try
        {
            var posts = await _postReviewService.GetFeedAsync(CurrentUserId, "discover", null, "saved", null, null, page, pageSize);
            return Ok(posts);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching saved posts for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }
}
