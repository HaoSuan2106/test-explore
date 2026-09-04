using ExploreMy.Api.Application.PostReview;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.PostReview;

namespace ExploreMy.Api.Tests;

/// <summary>
/// UNIT tests for PostDtoMapper entity → DTO mapping.
/// </summary>
public class PostDtoMapperTests
{
    private static Post MakePost(string authorName = "alice", int authorId = 1)
    {
        var author = new User { UserId = authorId, Username = authorName, ProfilePictureUrl = "http://avatar" };
        var place = new Place { PlaceId = "ChIJ-test", Name = "Test Cafe", Address = "Jalan Test" };
        return new Post
        {
            PostId = "post-1",
            AuthorId = authorId,
            Author = author,
            TaggedPlaceId = "ChIJ-test",
            TaggedPlace = place,
            Title = "Great place",
            Description = "Really nice",
            Images = new List<PostImage>
            {
                new() { ImageUrl = "http://img/1", DisplayOrder = 2 },
                new() { ImageUrl = "http://img/0", DisplayOrder = 1 },
            },
            Reactions = new List<PostReaction>(),
            Comments = new List<PostComment>(),
            Reports = new List<PostReport>(),
            ViewsCount = 42,
            Status = PostStatus.Active,
        };
    }

    [Fact]
    public void ToSummary_Maps_Images_In_DisplayOrder()
    {
        var dto = PostDtoMapper.ToSummary(MakePost(), 1);
        Assert.Equal(new[] { "http://img/0", "http://img/1" }, dto.ImageUrls);
    }

    [Fact]
    public void ToSummary_IsReacted_When_User_Reacted()
    {
        var post = MakePost();
        post.Reactions.Add(new PostReaction
        {
            PostId = post.PostId,
            UserId = 1,
            ReactionType = PostReactionType.Like,
            Status = PostReactionStatus.Active,
        });
        var dto = PostDtoMapper.ToSummary(post, 1);
        Assert.True(dto.IsReactedByCurrentUser);
        Assert.Equal(1, dto.ReactionCount);
    }

    [Fact]
    public void ToSummary_IsReported_When_User_Reported()
    {
        var post = MakePost();
        post.Reports.Add(new PostReport
        {
            PostId = post.PostId,
            ReporterId = 1,
            Reason = "Spam",
            Status = PostReportStatus.Active,
        });
        var dto = PostDtoMapper.ToSummary(post, 1);
        Assert.True(dto.IsReportedByCurrentUser);
        Assert.Equal(1, dto.ReportCount);
    }

    [Fact]
    public void ToSummary_IsSaved_From_SavedPostIds()
    {
        var dto = PostDtoMapper.ToSummary(MakePost(), 1, new HashSet<string> { "post-1" });
        Assert.True(dto.IsSavedByCurrentUser);
    }

    [Fact]
    public void ToSummary_Maps_Author_And_Place()
    {
        var dto = PostDtoMapper.ToSummary(MakePost(), 1);
        Assert.Equal("alice", dto.AuthorName);
        Assert.Equal("ChIJ-test", dto.TaggedPlaceId);
        Assert.Equal("Test Cafe", dto.TaggedPlaceName);
        Assert.Equal(42, dto.ViewsCount);
    }

    [Fact]
    public void ToDetails_Includes_Active_Comments()
    {
        var post = MakePost();
        var comments = new List<PostCommentDto>
        {
            new() { CommentId = "c1", Content = "hello" },
        };
        var dto = PostDtoMapper.ToDetails(post, 1, comments);
        Assert.Single(dto.Comments);
        Assert.Equal("c1", dto.Comments[0].CommentId);
    }

    [Fact]
    public void ToComment_Maps_Author_Name()
    {
        var comment = new PostComment
        {
            CommentId = "c1",
            PostId = "post-1",
            AuthorId = 2,
            Author = new User { UserId = 2, Username = "bob" },
            Content = "Nice!",
            LikesCount = 3,
        };
        var dto = PostDtoMapper.ToComment(comment);
        Assert.Equal("bob", dto.AuthorName);
        Assert.Equal("Nice!", dto.Content);
        Assert.Equal(3, dto.LikesCount);
    }

    [Fact]
    public void ToReport_Maps_Reporter_And_Reason()
    {
        var report = new PostReport
        {
            ReportId = "r1",
            PostId = "post-1",
            ReporterId = 2,
            Reason = "Spam",
            Status = PostReportStatus.Active,
        };
        var dto = PostDtoMapper.ToReport(report);
        Assert.Equal("2", dto.ReporterId);
        Assert.Equal("Spam", dto.Reason);
        Assert.Equal(PostReportStatus.Active, dto.Status);
    }
}