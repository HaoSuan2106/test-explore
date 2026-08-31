using ExploreMy.Api.Domain.Entities;

namespace ExploreMy.Api.DataAccess.Repositories.HiddenPlace;

/// <summary>
/// Kept separate from IHiddenPlaceRepository rather than added to it. That interface is shared with
/// the recommended-places module and is edited by more than one person; a suppression list is a
/// small, self-contained concern, and giving it its own file keeps the two out of each other's way.
/// </summary>
public interface IHiddenPlaceSuppressionRepository
{
    /// <summary>
    /// Every suppressed Google place id, as a set ready for membership checks.
    ///
    /// Loaded whole rather than queried per search because the list is small by nature - it only
    /// grows when five separate people report the same place - and one small read beats sending a
    /// few hundred candidate ids to the database on every search. Revisit if it ever reaches the
    /// thousands.
    /// </summary>
    Task<HashSet<string>> GetSuppressedPlaceIdsAsync();

    /// <summary>
    /// Records that a place must no longer be shown. Safe to call more than once for the same place:
    /// a repeat is ignored rather than treated as an error, so a report flow does not need to check
    /// first. System/legacy rows carry <see cref="HiddenPlaceSuppression.UserId"/> = 0.
    /// </summary>
    Task SuppressAsync(string placeId, string? name, string? reason, int reportCount);

    /// <summary>
    /// Returns the first suppression/tracking row for a recommended place (matched by its
    /// <c>recommend_place_id</c>), or <c>null</c> when that place has never been reported.
    /// </summary>
    Task<HiddenPlaceSuppression?> GetByRecommendedPlaceIdAsync(string recommendedPlaceId);

    /// <summary>
    /// Whether ONE user has an active report against a recommended place (matched by
    /// <c>recommend_place_id</c>). Place Report is one row per (user, place), so a per-user
    /// existence check is a single lookup — this is what lets the UI keep the Report Place
    /// card disabled after a reload (persisted state, not just same-session UI state).
    /// </summary>
    Task<bool> HasUserReportedRecommendedPlaceAsync(int userId, string recommendedPlaceId);

    /// <summary>
    /// Applies ONE user's report against a recommended place. Storage is one row per (user, place):
    /// a report creates a new row (<see cref="HiddenPlaceSuppression.UserId"/> = <paramref name="userId"/>,
    /// <c>ReportCount = 1</c>). Place Report is NOT a toggle and NOT an anonymous aggregate: when the
    /// same user has already reported the same place, <c>null</c> is returned and nothing is written
    /// (the UNIQUE(user_id, place_id) index backs this up at the database level). Returns the created
    /// row on a fresh report.
    /// </summary>
    Task<HiddenPlaceSuppression?> RecordReportAsync(
        int userId, string recommendedPlaceId, string placeId, string name, string reason);

    /// <summary>
    /// Applies ONE user's report against a Google-sourced place (no recommended-place submission).
    /// Storage is one row per (user, place): a report creates a new row with
    /// <c>RecommendedPlaceId = null</c>. Same-user repeats are rejected (returns <c>null</c>).
    /// Returns the created row on a fresh report.
    /// </summary>
    Task<HiddenPlaceSuppression?> RecordGooglePlaceReportAsync(int userId, string placeId, string name, string reason);

    /// <summary>
    /// Aggregate report counts keyed by <c>recommend_place_id</c> for the given recommended places.
    /// Places with no suppression row are absent from the dictionary (treated as 0 by callers).
    /// Each user report row contributes 1, so the sum equals the number of distinct active user
    /// reports (plus any legacy anonymous rows, which keep their historical ReportCount).
    /// </summary>
    Task<Dictionary<string, int>> GetReportCountsByRecommendedPlaceIdsAsync(IReadOnlyCollection<string> recommendedPlaceIds);

    /// <summary>
    /// Total report count for a single place, matched by <c>place_id</c> (works for both community
    /// and Google-origin rows). Sums <c>ReportCount</c> over every row for that place.
    /// </summary>
    Task<int> GetReportCountByPlaceIdAsync(string placeId);
}
