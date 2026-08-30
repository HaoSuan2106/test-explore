namespace ExploreMy.Api.DTOs.HiddenPlace;

public class HiddenPlaceReviewPhotoDto
{
    public long ReviewPhotoId { get; set; }

    public long ReviewId { get; set; }

    public string PhotoUrl { get; set; } = string.Empty;

    public int DisplayOrder { get; set; }

    public DateTime CreatedAt { get; set; }
}