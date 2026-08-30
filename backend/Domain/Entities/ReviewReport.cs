namespace ExploreMy.Api.Domain.Entities;

public class ReviewReport
{
    public long ReportId { get; set; }

    public long ReviewId { get; set; }

    public int UserId { get; set; }

    public string Reason { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }
}