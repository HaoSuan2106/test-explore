using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.FootTracker;
using ExploreMy.Api.DTOs.PostReview;

namespace ExploreMy.Api.Application.PostReview;

/// <summary>Shared entity → DTO mapping for the Post module.</summary>
public static class PostDtoMapper
{
    public static PostSummaryDto ToSummary(Post post, int currentUserId, HashSet<string>? savedPostIds = null)
    {
        var images = post.Images
            .OrderBy(i => i.DisplayOrder)
            .Select(i => i.ImageUrl)
            .ToList();

        return new PostSummaryDto
        {
            PostId = post.PostId,
            AuthorId = post.AuthorId.ToString(),
            AuthorName = post.Author?.Username ?? string.Empty,
            AuthorAvatarUrl = post.Author?.ProfilePictureUrl,
            TaggedPlaceId = post.TaggedPlaceId,
            TaggedPlaceName = post.TaggedPlace?.Name ?? string.Empty,
            TaggedPlaceAddress = post.TaggedPlace?.Address ?? string.Empty,
            Title = post.Title,
            Description = post.Description,
            ImageUrls = images,
            ReactionCount = post.Reactions.Count(r => r.Status == PostReactionStatus.Active),
            CommentCount = post.Comments.Count(c => c.Status == PostCommentStatus.Active),
            ReportCount = post.Reports.Count(r => r.Status == PostReportStatus.Active),
            IsReactedByCurrentUser = post.Reactions.Any(r => r.UserId == currentUserId
                                                              && r.Status == PostReactionStatus.Active),
            IsReportedByCurrentUser = post.Reports.Any(r => r.ReporterId == currentUserId
                                                            && r.Status == PostReportStatus.Active),
            IsSavedByCurrentUser = savedPostIds?.Contains(post.PostId) ?? false,
            ViewsCount = post.ViewsCount,
            Status = post.Status,
            CreatedAt = post.CreatedAt,
            UpdatedAt = post.UpdatedAt,
        };
    }

    public static PostDetailsDto ToDetails(Post post, int currentUserId, List<PostCommentDto> comments, HashSet<string>? savedPostIds = null)
    {
        var summary = ToSummary(post, currentUserId, savedPostIds);
        return new PostDetailsDto
        {
            PostId = summary.PostId,
            AuthorId = summary.AuthorId,
            AuthorName = summary.AuthorName,
            AuthorAvatarUrl = summary.AuthorAvatarUrl,
            TaggedPlaceId = summary.TaggedPlaceId,
            TaggedPlaceName = summary.TaggedPlaceName,
            TaggedPlaceAddress = summary.TaggedPlaceAddress,
            Title = summary.Title,
            Description = summary.Description,
            ImageUrls = summary.ImageUrls,
            ReactionCount = summary.ReactionCount,
            CommentCount = summary.CommentCount,
            ReportCount = summary.ReportCount,
            IsReactedByCurrentUser = summary.IsReactedByCurrentUser,
            IsReportedByCurrentUser = summary.IsReportedByCurrentUser,
            IsSavedByCurrentUser = summary.IsSavedByCurrentUser,
            ViewsCount = summary.ViewsCount,
            Status = summary.Status,
            CreatedAt = summary.CreatedAt,
            UpdatedAt = summary.UpdatedAt,
            Comments = comments,
            Reports = post.Reports
                .Where(r => r.Status == PostReportStatus.Active)
                .Select(ToReport)
                .ToList(),
        };
    }

    public static PostCommentDto ToComment(PostComment comment) => new()
    {
        CommentId = comment.CommentId,
        PostId = comment.PostId,
        PostTitle = comment.Post?.Title ?? string.Empty,
        AuthorId = comment.AuthorId.ToString(),
        AuthorName = comment.Author?.Username ?? string.Empty,
        AuthorAvatarUrl = comment.Author?.ProfilePictureUrl,
        Content = comment.Content,
        LikesCount = comment.LikesCount,
        CreatedAt = comment.CreatedAt,
        UpdatedAt = comment.UpdatedAt,
    };

    public static PostReportDto ToReport(PostReport report) => new()
    {
        ReportId = report.ReportId,
        PostId = report.PostId,
        ReporterId = report.ReporterId.ToString(),
        Reason = report.Reason,
        Status = report.Status,
        CreatedAt = report.CreatedAt,
        WithdrawnAt = report.WithdrawnAt,
        PostTitle = report.Post?.Title ?? string.Empty,
        PostedBy = report.Post?.Author?.Username ?? string.Empty,
        TaggedPlaceName = report.Post?.TaggedPlace?.Name ?? string.Empty,
        PostDescription = report.Post?.Description ?? string.Empty,
        PostImageUrl = report.Post?.Images
            .OrderBy(i => i.DisplayOrder)
            .Select(i => i.ImageUrl)
            .FirstOrDefault() ?? string.Empty,
        ReactionCount = report.Post?.Reactions.Count(r => r.Status == PostReactionStatus.Active) ?? 0,
        CommentCount = report.Post?.Comments.Count(c => c.Status == PostCommentStatus.Active) ?? 0,
    };

    /// <summary>
    /// Maps a real FootTracker visit (VisitLogDto) into the API response DTO.
    /// VisitLogDto carries no Description field, so that property is mapped
    /// as null (reported in the Recommendation migration audit).
    /// </summary>
    public static VisitedAttractionDto ToVisitedAttraction(VisitLogDto visit) => new()
    {
        PlaceId = visit.PlaceId ?? string.Empty,
        Name = visit.Title ?? string.Empty,
        Address = visit.Address ?? string.Empty,
        Category = visit.PrimaryType ?? string.Empty,
        Description = null, // VisitLogDto has no description field
    };
}
