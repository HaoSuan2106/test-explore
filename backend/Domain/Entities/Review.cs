namespace ExploreMy.Api.Domain.Entities;

public class Review
{
    public long ReviewId { get; set; }

    public string? GooglePlaceId { get; set; }

    public string? RecommendPlaceId { get; set; }

    public int UserId { get; set; }

    public decimal Rating { get; set; }

    public string Comment { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public string Status { get; set; } = "ACTIVE";
}