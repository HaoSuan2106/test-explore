using ExploreMy.Api.Application.PostReview.SocialEngagement;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.Repositories.PostReview;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.PostReview;
using Microsoft.Extensions.Logging;
using Moq;

namespace ExploreMy.Backend.Tests;

public class SocialEngagementServiceTests
{
    private readonly Mock<IPostReviewRepository> _repository = new();
    private readonly Mock<ILogger<SocialEngagementService>> _logger = new();

    private SocialEngagementService CreateService() => new(_repository.Object, _logger.Object);

    private static Post CreatePost(string postId = "post-1", int authorId = 1) => new()
    {
        PostId = postId,
        AuthorId = authorId,
        Title = "A great spot",
        Description = "Beautiful place to visit.",
        Status = PostStatus.Active,
    };

    private static PostComment CreateComment(
        string commentId = "comment-1",
        int authorId = 2,
        string postId = "post-1",
        string content = "Nice post!") => new()
    {
        CommentId = commentId,
        PostId = postId,
        AuthorId = authorId,
        Content = content,
        Status = PostCommentStatus.Active,
    };

    // ============================================================
    // CreateComment
    // ============================================================

    [Fact]
    public async Task AddComment_ValidComment_CreatesSuccessfully()
    {
        var service = CreateService();
        _repository.Setup(r => r.PostExistsAsync("post-1")).ReturnsAsync(true);
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);
        _repository.Setup(r => r.GetCommentByIdAsync(It.IsAny<string>())).ReturnsAsync((string id) => CreateComment(id));

        var result = await service.CreateCommentAsync(1, "post-1", new CreateCommentRequestDto { Content = "Nice post!" });

        Assert.Equal("Comment added successfully.", result.Message);
        Assert.NotNull(result.Comment);
        _repository.Verify(r => r.CreateCommentAsync(It.Is<PostComment>(c =>
            c.PostId == "post-1"
            && c.AuthorId == 1
            && c.Content == "Nice post!"
            && c.Status == PostCommentStatus.Active)), Times.Once);
    }

    [Fact]
    public async Task AddComment_EmptyContent_ThrowsValidationException()
    {
        var service = CreateService();

        await Assert.ThrowsAsync<ValidationException>(() =>
            service.CreateCommentAsync(1, "post-1", new CreateCommentRequestDto { Content = "   " }));
        _repository.Verify(r => r.CreateCommentAsync(It.IsAny<PostComment>()), Times.Never);
    }

    [Fact]
    public async Task AddComment_ContentOver100Chars_ThrowsValidationException()
    {
        var service = CreateService();
        var longContent = new string('a', PostCommentLimits.MaxContentLength + 1);

        await Assert.ThrowsAsync<ValidationException>(() =>
            service.CreateCommentAsync(1, "post-1", new CreateCommentRequestDto { Content = longContent }));
        _repository.Verify(r => r.CreateCommentAsync(It.IsAny<PostComment>()), Times.Never);
    }

    [Fact]
    public async Task AddComment_NonexistentPost_ThrowsNotFoundException()
    {
        var service = CreateService();
        _repository.Setup(r => r.PostExistsAsync("post-1")).ReturnsAsync(false);

        await Assert.ThrowsAsync<NotFoundException>(() =>
            service.CreateCommentAsync(1, "post-1", new CreateCommentRequestDto { Content = "Nice post!" }));
        _repository.Verify(r => r.CreateCommentAsync(It.IsAny<PostComment>()), Times.Never);
    }

    [Fact]
    public async Task AddComment_OwnPost_ThrowsForbiddenException()
    {
        // Frozen rule: a user must not comment on their own community post.
        var service = CreateService();
        _repository.Setup(r => r.PostExistsAsync("post-1")).ReturnsAsync(true);
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost(authorId: 1));

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            service.CreateCommentAsync(1, "post-1", new CreateCommentRequestDto { Content = "Nice post!" }));
        _repository.Verify(r => r.CreateCommentAsync(It.IsAny<PostComment>()), Times.Never);
    }

    [Fact]
    public async Task AddComment_ReportedUser_ThrowsForbiddenException()
    {
        // A user with an active report on the post is view-only.
        var service = CreateService();
        _repository.Setup(r => r.PostExistsAsync("post-1")).ReturnsAsync(true);
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(true);

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            service.CreateCommentAsync(1, "post-1", new CreateCommentRequestDto { Content = "Nice post!" }));
        _repository.Verify(r => r.CreateCommentAsync(It.IsAny<PostComment>()), Times.Never);
    }

    // ============================================================
    // UpdateComment
    // ============================================================

    [Fact]
    public async Task EditComment_OwnComment_Updates()
    {
        var service = CreateService();
        var comment = CreateComment(authorId: 1);
        _repository.Setup(r => r.GetCommentByIdAsync("comment-1")).ReturnsAsync(comment);
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);

        var result = await service.UpdateCommentAsync(1, "comment-1", new UpdateCommentRequestDto { Content = "Updated content." });

        Assert.Equal("Comment updated successfully.", result.Message);
        Assert.Equal("Updated content.", comment.Content);
        _repository.Verify(r => r.UpdateCommentAsync(comment), Times.Once);
    }

    [Fact]
    public async Task EditComment_OtherUsersComment_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetCommentByIdAsync("comment-1")).ReturnsAsync(CreateComment(authorId: 3));

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            service.UpdateCommentAsync(1, "comment-1", new UpdateCommentRequestDto { Content = "Hacked" }));
        _repository.Verify(r => r.UpdateCommentAsync(It.IsAny<PostComment>()), Times.Never);
    }

    // ============================================================
    // DeleteComment
    // ============================================================

    [Fact]
    public async Task DeleteComment_OwnComment_Deletes()
    {
        var service = CreateService();
        var comment = CreateComment(authorId: 1);
        _repository.Setup(r => r.GetCommentByIdAsync("comment-1")).ReturnsAsync(comment);
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);

        var result = await service.DeleteCommentAsync(1, "comment-1");

        Assert.Equal("comment-1", result.CommentId);
        Assert.Equal(PostCommentStatus.Deleted, comment.Status);
        _repository.Verify(r => r.UpdateCommentAsync(comment), Times.Once);
    }

    [Fact]
    public async Task DeleteComment_OtherUsersComment_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetCommentByIdAsync("comment-1")).ReturnsAsync(CreateComment(authorId: 3));

        await Assert.ThrowsAsync<ForbiddenException>(() => service.DeleteCommentAsync(1, "comment-1"));
        _repository.Verify(r => r.UpdateCommentAsync(It.IsAny<PostComment>()), Times.Never);
    }

    // ============================================================
    // ToggleReaction (toggle semantics)
    // ============================================================

    [Fact]
    public async Task AddReaction_ValidToggle_AddsReaction()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost());
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);
        _repository.Setup(r => r.GetActiveReactionAsync("post-1", 1)).ReturnsAsync((PostReaction?)null);
        _repository.Setup(r => r.GetAnyReactionAsync("post-1", 1)).ReturnsAsync((PostReaction?)null);
        _repository.Setup(r => r.GetActiveReactionCountAsync("post-1")).ReturnsAsync(1);

        var result = await service.ToggleReactionAsync(1, "post-1", new ToggleReactionRequestDto { ReactionType = PostReactionType.Like });

        Assert.True(result.IsReacted);
        Assert.Equal(1, result.ReactionCount);
        _repository.Verify(r => r.CreateReactionAsync(It.Is<PostReaction>(re =>
            re.PostId == "post-1"
            && re.UserId == 1
            && re.ReactionType == PostReactionType.Like
            && re.Status == PostReactionStatus.Active)), Times.Once);
    }

    [Fact]
    public async Task RemoveReaction_ToggleRemovesWhenAlreadyActive()
    {
        var service = CreateService();
        var active = new PostReaction
        {
            PostId = "post-1",
            UserId = 1,
            ReactionType = PostReactionType.Like,
            Status = PostReactionStatus.Active,
        };
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost());
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);
        _repository.Setup(r => r.GetActiveReactionAsync("post-1", 1)).ReturnsAsync(active);
        _repository.Setup(r => r.GetActiveReactionCountAsync("post-1")).ReturnsAsync(0);

        var result = await service.ToggleReactionAsync(1, "post-1", new ToggleReactionRequestDto { ReactionType = PostReactionType.Like });

        Assert.False(result.IsReacted);
        Assert.Equal(PostReactionStatus.Withdrawn, active.Status);
        _repository.Verify(r => r.UpdateReactionAsync(active), Times.Once);
        _repository.Verify(r => r.CreateReactionAsync(It.IsAny<PostReaction>()), Times.Never);
    }

    [Fact]
    public async Task DuplicateReaction_SecondToggle_Removes()
    {
        // Toggle semantics: first toggle adds, second toggle removes.
        var service = CreateService();
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost());
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);
        _repository.Setup(r => r.GetActiveReactionCountAsync("post-1")).ReturnsAsync(1);
        _repository.SetupSequence(r => r.GetActiveReactionAsync("post-1", 1))
            .ReturnsAsync((PostReaction?)null) // 1st call: not reacted yet → add
            .ReturnsAsync(new PostReaction
            {
                PostId = "post-1",
                UserId = 1,
                ReactionType = PostReactionType.Like,
                Status = PostReactionStatus.Active,
            }); // 2nd call: already reacted → remove

        var first = await service.ToggleReactionAsync(1, "post-1", new ToggleReactionRequestDto { ReactionType = PostReactionType.Like });
        Assert.True(first.IsReacted);
        _repository.Verify(r => r.CreateReactionAsync(It.IsAny<PostReaction>()), Times.Once);

        var second = await service.ToggleReactionAsync(1, "post-1", new ToggleReactionRequestDto { ReactionType = PostReactionType.Like });
        Assert.False(second.IsReacted);
        _repository.Verify(r => r.UpdateReactionAsync(It.IsAny<PostReaction>()), Times.Once);
        _repository.Verify(r => r.CreateReactionAsync(It.IsAny<PostReaction>()), Times.Once);
    }

    // ============================================================
    // CreateReport
    // ============================================================

    [Fact]
    public async Task Report_ValidReport_CreatesRecord()
    {
        var service = CreateService();
        _repository.Setup(r => r.PostExistsAsync("post-1")).ReturnsAsync(true);
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(false);
        _repository.Setup(r => r.GetActiveReportCountAsync("post-1")).ReturnsAsync(1);

        var result = await service.CreateReportAsync(1, "post-1", new CreateReportRequestDto { Reason = PostReportReasons.OtherViolation });

        Assert.Equal("Report submitted successfully.", result.Message);
        Assert.False(string.IsNullOrEmpty(result.ReportId));
        Assert.Equal(1, result.ReportCount);
        _repository.Verify(r => r.CreateReportAsync(It.Is<PostReport>(rep =>
            rep.PostId == "post-1"
            && rep.ReporterId == 1
            && rep.Reason == PostReportReasons.OtherViolation
            && rep.Status == PostReportStatus.Active)), Times.Once);
    }

    [Fact]
    public async Task Report_InvalidReason_ThrowsValidationException()
    {
        var service = CreateService();

        await Assert.ThrowsAsync<ValidationException>(() =>
            service.CreateReportAsync(1, "post-1", new CreateReportRequestDto { Reason = "Not a valid reason" }));
        _repository.Verify(r => r.CreateReportAsync(It.IsAny<PostReport>()), Times.Never);
    }

    [Fact]
    public async Task Report_DuplicateActiveReport_ThrowsValidationException()
    {
        var service = CreateService();
        _repository.Setup(r => r.PostExistsAsync("post-1")).ReturnsAsync(true);
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost(authorId: 2));
        _repository.Setup(r => r.HasActiveReportAsync("post-1", 1)).ReturnsAsync(true);

        await Assert.ThrowsAsync<ValidationException>(() =>
            service.CreateReportAsync(1, "post-1", new CreateReportRequestDto { Reason = PostReportReasons.OtherViolation }));
        _repository.Verify(r => r.CreateReportAsync(It.IsAny<PostReport>()), Times.Never);
    }

    [Fact]
    public async Task Report_OwnPost_ThrowsForbiddenException()
    {
        var service = CreateService();
        _repository.Setup(r => r.PostExistsAsync("post-1")).ReturnsAsync(true);
        _repository.Setup(r => r.GetByIdAsync("post-1", 1)).ReturnsAsync(CreatePost(authorId: 1));

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            service.CreateReportAsync(1, "post-1", new CreateReportRequestDto { Reason = PostReportReasons.OtherViolation }));
        _repository.Verify(r => r.CreateReportAsync(It.IsAny<PostReport>()), Times.Never);
    }

    // ============================================================
    // GetMyReports
    // ============================================================

    [Fact]
    public async Task GetMyReports_ReturnsReports()
    {
        var service = CreateService();
        _repository.Setup(r => r.GetReportsByReporterAsync(1)).ReturnsAsync(new List<PostReport>
        {
            new()
            {
                ReportId = "report-1",
                PostId = "post-1",
                ReporterId = 1,
                Reason = PostReportReasons.OtherViolation,
                Status = PostReportStatus.Active,
            },
        });

        var result = await service.GetMyReportsAsync(1);

        var report = Assert.Single(result);
        Assert.Equal("report-1", report.ReportId);
        Assert.Equal("post-1", report.PostId);
        Assert.Equal(PostReportReasons.OtherViolation, report.Reason);
    }

    // ============================================================
    // D5: reports are terminal — no withdrawal method on the interface.
    // This is enforced at compile time: any attempt to call
    // `service.WithdrawReportAsync(...)` would not compile, and if someone
    // ever adds a `WithdrawReportAsync` to ISocialEngagementService this
    // reflection assertion fails as an extra safety net.
    // ============================================================

    [Fact]
    public void NoWithdrawReportAsyncMethodExistsOnInterface()
    {
        var method = typeof(ISocialEngagementService).GetMethod("WithdrawReportAsync");

        Assert.Null(method);
    }
}
