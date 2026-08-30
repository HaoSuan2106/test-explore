namespace ExploreMy.Api.Domain.Entities;

public class ReviewPhoto
{
    public long ReviewPhotoId { get; set; }

    public long ReviewId { get; set; }

    public string PhotoUrl { get; set; } = string.Empty;

    public int DisplayOrder { get; set; }

    public DateTime CreatedAt { get; set; }
}