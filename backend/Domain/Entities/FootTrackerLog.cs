namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A foot-tracker exploration log. Used by the Post module to determine the
/// eligible attractions (distinct explored places) of an authenticated user.
/// Maps to the <c>foot_tracker_log</c> table (shared FootTracker-module dependency).
/// </summary>
public class FootTrackerLog
{
    public string LogId { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string? PlaceId { get; set; }
    public string? Title { get; set; }
    public decimal? DistanceKm { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? EndedAt { get; set; }
    public string Status { get; set; } = FootTrackerLogStatus.InProgress;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public Place? Place { get; set; }
    public User? User { get; set; }
}

public static class FootTrackerLogStatus
{
    public const string InProgress = "IN_PROGRESS";
    public const string Completed = "COMPLETED";
    public const string Cancelled = "CANCELLED";
}
