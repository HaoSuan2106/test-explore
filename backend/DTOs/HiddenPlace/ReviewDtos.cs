namespace ExploreMy.Api.DTOs.HiddenPlace;

public class CreateHiddenPlaceReviewRequestDto
{
    public string? GooglePlaceId { get; set; }

    public string? RecommendPlaceId { get; set; }

    public decimal Rating { get; set; }

    public string Comment { get; set; } = string.Empty;
}

public class UpdateHiddenPlaceReviewRequestDto
{
    public decimal Rating { get; set; }

    public string Comment { get; set; } = string.Empty;
}

public class HiddenPlaceReviewDto
{
    public long ReviewId { get; set; }

    public string? GooglePlaceId { get; set; }

    public string? RecommendPlaceId { get; set; }

    public int UserId { get; set; }

    public string? Username { get; set; }

    public string? ProfilePictureUrl { get; set; }
    public List<HiddenPlaceReviewPhotoDto> Photos { get; set; } = new();

    public decimal Rating { get; set; }

    public string Comment { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public string Status { get; set; } = "ACTIVE";
}