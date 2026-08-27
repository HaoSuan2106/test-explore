namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A saved-post relationship: a user bookmarks a post for quick access.
/// Maps to the <c>user_saved_posts</c> table.
/// UNIQUE(post_id, user_id) prevents duplicate saves.
/// </summary>
public class UserSavedPost
{
    public string SavedId { get; set; } = Guid.NewGuid().ToString();
    public string PostId { get; set; } = string.Empty;
    public int UserId { get; set; }
    public DateTime CreatedAt { get; set; }

    // Navigation
    public Post? Post { get; set; }
    public User? User { get; set; }
}