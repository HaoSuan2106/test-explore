using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.Repositories.PostReview;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.PostReview;

namespace ExploreMy.Api.Application.PostReview.SocialEngagement;

public class SocialEngagementService : ISocialEngagementService
{
    private readonly IPostReviewRepository _repository;
    private readonly ILogger<SocialEngagementService> _logger;

    public SocialEngagementService(IPostReviewRepository repository, ILogger<SocialEngagementService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    // ---------------- Comments ----------------

    public async Task<List<PostCommentDto>> GetCommentsAsync(string postId)
    {
        var comments = await _repository.GetCommentsByPostAsync(postId);
        return comments.Select(PostDtoMapper.ToComment).ToList();
    }

    public async Task<List<PostCommentDto>> GetMyCommentsAsync(int currentUserId)
    {
        var comments = await _repository.GetCommentsByAuthorAsync(currentUserId);
        return comments.Select(PostDtoMapper.ToComment).ToList();
    }

    public async Task<CreateCommentResponseDto> CreateCommentAsync(int currentUserId, string postId, CreateCommentRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.Content))
        {
            throw new ValidationException("Comment cannot be empty.");
        }

        if (request.Content.Length > PostCommentLimits.MaxContentLength)
        {
            throw new ValidationException($"Comment must not exceed {PostCommentLimits.MaxContentLength} characters.");
        }

        if (!await _repository.PostExistsAsync(postId))
        {
            throw new NotFoundException("Post not found.");
        }

        // REQ: users must not comment on their own community post.
        var post = await _repository.GetByIdAsync(postId, currentUserId)
            ?? throw new NotFoundException("Post not found.");
        if (post.AuthorId == currentUserId)
        {
            throw new ForbiddenException("You cannot comment on your own post.");
        }

        // REQ: reporters with an active report on this post are view-only.
        if (await _repository.HasActiveReportAsync(postId, currentUserId))
        {
            throw new ForbiddenException("You have reported this post. You cannot comment while your report is active.");
        }

        var comment = new PostComment
        {
            PostId = postId,
            AuthorId = currentUserId,
            Content = request.Content.Trim(),
            Status = PostCommentStatus.Active,
        };

        await _repository.CreateCommentAsync(comment);

        // Reload to include author navigation
        var saved = await _repository.GetCommentByIdAsync(comment.CommentId);

        _logger.LogInformation("User {UserId} commented on post {PostId}.", currentUserId, postId);
        return new CreateCommentResponseDto
        {
            Comment = saved is null ? null! : PostDtoMapper.ToComment(saved),
            Message = "Comment added successfully.",
        };
    }

    public async Task<UpdateCommentResponseDto> UpdateCommentAsync(int currentUserId, string commentId, UpdateCommentRequestDto request)
    {
        var comment = await _repository.GetCommentByIdAsync(commentId)
                      ?? throw new NotFoundException("Comment not found.");

        if (comment.AuthorId != currentUserId)
        {
            throw new ForbiddenException("You can only modify your own comments.");
        }

        if (comment.Status != PostCommentStatus.Active)
        {
            throw new ForbiddenException("This comment can no longer be edited.");
        }

        // REQ: reporters with an active report on the post are view-only — they
        // cannot modify (even their own) existing comments on that post.
        if (await _repository.HasActiveReportAsync(comment.PostId, currentUserId))
        {
            throw new ForbiddenException("You have reported this post. You cannot edit comments while your report is active.");
        }

        if (string.IsNullOrWhiteSpace(request.Content))
        {
            throw new ValidationException("Comment cannot be empty.");
        }

        if (request.Content.Length > PostCommentLimits.MaxContentLength)
        {
            throw new ValidationException($"Comment must not exceed {PostCommentLimits.MaxContentLength} characters.");
        }

        comment.Content = request.Content.Trim();
        await _repository.UpdateCommentAsync(comment);

        var updated = await _repository.GetCommentByIdAsync(commentId);
        _logger.LogInformation("User {UserId} updated comment {CommentId}.", currentUserId, commentId);
        return new UpdateCommentResponseDto
        {
            Comment = updated is null ? null! : PostDtoMapper.ToComment(updated),
            Message = "Comment updated successfully.",
        };
    }

    public async Task<DeleteCommentResponseDto> DeleteCommentAsync(int currentUserId, string commentId)
    {
        var comment = await _repository.GetCommentByIdAsync(commentId)
                      ?? throw new NotFoundException("Comment not found.");

        if (comment.AuthorId != currentUserId)
        {
            throw new ForbiddenException("You can only delete your own comments.");
        }

        // REQ: reporters with an active report on the post are view-only — they
        // cannot delete (even their own) existing comments on that post.
        if (await _repository.HasActiveReportAsync(comment.PostId, currentUserId))
        {
            throw new ForbiddenException("You have reported this post. You cannot delete comments while your report is active.");
        }

        comment.Status = PostCommentStatus.Deleted;
        await _repository.UpdateCommentAsync(comment);

        _logger.LogInformation("User {UserId} deleted comment {CommentId}.", currentUserId, commentId);
        return new DeleteCommentResponseDto
        {
            CommentId = commentId,
            Message = "Comment deleted successfully.",
        };
    }

    // ---------------- Reactions ----------------

    public async Task<ToggleReactionResponseDto> ToggleReactionAsync(int currentUserId, string postId, ToggleReactionRequestDto request)
    {
        // L-02: use the visibility-aware load (active post, and not hidden from
        // this user) so hidden posts cannot be liked by non-authors/non-reporters.
        var post = await _repository.GetByIdAsync(postId, currentUserId);
        if (post is null)
        {
            throw new NotFoundException("Post not found.");
        }

        // L-16: only the supported reaction type is accepted.
        if (request.ReactionType != PostReactionType.Like)
        {
            throw new ValidationException($"Reaction type '{request.ReactionType}' is not supported. Only '{PostReactionType.Like}' is allowed.");
        }

        // REQ: reporters with an active report on this post are view-only — they
        // cannot like/react while their report is active.
        if (await _repository.HasActiveReportAsync(postId, currentUserId))
        {
            throw new ForbiddenException("You have reported this post. You cannot react while your report is active.");
        }

        var active = await _repository.GetActiveReactionAsync(postId, currentUserId);

        if (active is not null)
        {
            // Withdraw (remove) the reaction
            active.Status = PostReactionStatus.Withdrawn;
            await _repository.UpdateReactionAsync(active);
        }
        else
        {
            // If a previously-withdrawn reaction exists, reactivate it instead of
            // inserting a new row (required by the UNIQUE(post_id, user_id) constraint
            // and the like-toggle behaviour, REQ501_11).
            var prior = await _repository.GetAnyReactionAsync(postId, currentUserId);
            if (prior is not null)
            {
                prior.Status = PostReactionStatus.Active;
                prior.ReactionType = request.ReactionType;
                prior.UpdatedAt = DateTime.UtcNow;
                await _repository.UpdateReactionAsync(prior);
            }
            else
            {
                // Add the reaction
                await _repository.CreateReactionAsync(new PostReaction
                {
                    PostId = postId,
                    UserId = currentUserId,
                    ReactionType = request.ReactionType,
                    Status = PostReactionStatus.Active,
                });
            }
        }

        var count = await _repository.GetActiveReactionCountAsync(postId);

        return new ToggleReactionResponseDto
        {
            PostId = postId,
            ReactionType = request.ReactionType,
            IsReacted = active is null,
            ReactionCount = count,
        };
    }

    // ---------------- Reports ----------------

    public async Task<CreateReportResponseDto> CreateReportAsync(int currentUserId, string postId, CreateReportRequestDto request)
    {
        if (!PostReportReasons.All.Contains(request.Reason))
        {
            throw new ValidationException("Invalid report reason.");
        }

        if (!await _repository.PostExistsAsync(postId))
        {
            throw new NotFoundException("Post not found.");
        }

        var post = await _repository.GetByIdAsync(postId, currentUserId)
            ?? throw new NotFoundException("Post not found.");

        if (post.AuthorId == currentUserId)
        {
            throw new ForbiddenException("You cannot report your own post.");
        }

        if (await _repository.HasActiveReportAsync(postId, currentUserId))
        {
            throw new ValidationException("You have already reported this post.");
        }

        // D5: reports are terminal — there is no withdrawal and no reactivation.
        var report = new PostReport
        {
            PostId = postId,
            ReporterId = currentUserId,
            Reason = request.Reason,
            Status = PostReportStatus.Active,
        };

        await _repository.CreateReportAsync(report);

        var count = await _repository.GetActiveReportCountAsync(postId);

        _logger.LogInformation("User {UserId} reported post {PostId} with reason '{Reason}'.", currentUserId, postId, request.Reason);
        return new CreateReportResponseDto
        {
            ReportId = report.ReportId,
            PostId = postId,
            ReportCount = count,
            Message = "Report submitted successfully.",
        };
    }

    public async Task<List<PostReportDto>> GetMyReportsAsync(int currentUserId)
    {
        var reports = await _repository.GetReportsByReporterAsync(currentUserId);
        return reports.Select(PostDtoMapper.ToReport).ToList();
    }

    public IReadOnlyList<string> GetReportReasons() => PostReportReasons.All;
}