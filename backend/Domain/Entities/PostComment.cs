namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A comment submitted by an authenticated user on a community post.
/// Maps to the <c>community_post_comments</c> table.
/// </summary>
public class PostComment
{
    public string CommentId { get; set; } = Guid.NewGuid().ToString();
    public string PostId { get; set; } = string.Empty;
    public int AuthorId { get; set; }
    public string Content { get; set; } = string.Empty;
    public int LikesCount { get; set; }
    public string Status { get; set; } = PostCommentStatus.Active;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public Post? Post { get; set; }
    public User? Author { get; set; }
}

public static class PostCommentStatus
{
    public const string Active = "ACTIVE";
    public const string Deleted = "DELETED";
}

public static class PostCommentLimits
{
    public const int MaxContentLength = 100;
}
