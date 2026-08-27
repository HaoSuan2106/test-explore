namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// An image attached to a community post (max five per post, JPEG/PNG, max 5 MB).
/// Maps to the <c>community_post_images</c> table.
/// </summary>
public class PostImage
{
    public string ImageId { get; set; } = Guid.NewGuid().ToString();
    public string PostId { get; set; } = string.Empty;
    public string ImageUrl { get; set; } = string.Empty;
    public short DisplayOrder { get; set; } = 1;
    public DateTime CreatedAt { get; set; }

    // Navigation
    public Post? Post { get; set; }
}

public static class PostImageLimits
{
    public const int MaxImages = 5;
    public const long MaxSizeBytes = 5 * 1024 * 1024;
    public const short MinDisplayOrder = 1;
    public const short MaxDisplayOrder = 5;
}
