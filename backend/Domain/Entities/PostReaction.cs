namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A Love reaction by an authenticated user on a community post.
/// A user may have at most one ACTIVE reaction per post (toggled to WITHDRAWN).
/// Maps to the <c>community_post_reactions</c> table.
/// </summary>
public class PostReaction
{
    public string ReactionId { get; set; } = Guid.NewGuid().ToString();
    public string PostId { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string ReactionType { get; set; } = PostReactionType.Like;
    public string Status { get; set; } = PostReactionStatus.Active;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public Post? Post { get; set; }
    public User? User { get; set; }
}

public static class PostReactionType
{
    public const string Like = "LIKE";
}

public static class PostReactionStatus
{
    public const string Active = "ACTIVE";
    public const string Withdrawn = "WITHDRAWN";
}
