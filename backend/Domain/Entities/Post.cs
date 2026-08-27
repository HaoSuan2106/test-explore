namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A community post created by an authenticated user, optionally tagging an
/// attraction from the user's exploration history and carrying up to five images.
/// Maps to the <c>community_posts</c> table.
/// </summary>
public class Post
{
    public string PostId { get; set; } = Guid.NewGuid().ToString();
    public int AuthorId { get; set; }
    public string TaggedPlaceId { get; set; } = string.Empty;
    public string? Title { get; set; }
    public string Description { get; set; } = string.Empty;
    public int ViewsCount { get; set; }
    public string Status { get; set; } = PostStatus.Active;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public User? Author { get; set; }
    public Place? TaggedPlace { get; set; }
    public ICollection<PostImage> Images { get; set; } = new List<PostImage>();
    public ICollection<PostComment> Comments { get; set; } = new List<PostComment>();
    public ICollection<PostReaction> Reactions { get; set; } = new List<PostReaction>();
    public ICollection<PostReport> Reports { get; set; } = new List<PostReport>();
    public ICollection<UserSavedPost> Saves { get; set; } = new List<UserSavedPost>();
}

public static class PostStatus
{
    public const string Active = "ACTIVE";
    public const string Deleted = "DELETED";
}

public static class PostLimits
{
    /// <summary>Maximum length of the post title (business decision H-4 — title is compulsory).</summary>
    public const int MaxTitleLength = 100;

    /// <summary>Maximum length of the post description (REQ501_4/5).</summary>
    public const int MaxDescriptionLength = 2000;
}
