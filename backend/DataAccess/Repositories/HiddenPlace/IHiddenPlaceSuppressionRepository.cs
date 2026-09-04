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
    /// Every suppressed place id, as a set ready for membership checks.
    ///
    /// Suppressed means the reports against it total at least
    /// <see cref="RecommendedPlaceThresholds.HideThreshold"/> - NOT merely that someone reported it
    /// once. A row in this table is one person's report; it takes that many of them to hide a place.
    ///
    /// Loaded whole rather than queried per search because the list is small by nature - it only
    /// grows when five separate people report the same place - and one small read beats sending a
    /// few hundred candidate ids to the database on every search. Revisit if it ever reaches the
    /// thousands.
    /// </summary>
    Task<HashSet<string>> GetSuppressedPlaceIdsAsync();

    /// <summary>
    /// Whether the user already has an active report row for this <c>place_id</c>
    /// (works for both recommended places and Google-sourced places).
    /// </summary>
    Task<bool> ExistsAsync(int userId, string placeId);

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
    /// <c>ReportCount = 1</c>). Place Report is NOT a toggle and NOT an anonymous aggregate: the
    /// duplicate-report decision is the service layer's (it calls <see cref="ExistsAsync"/> first,
    /// V-11). This method persists and surfaces the UNIQUE(user_id, place_id) constraint only —
    /// a concurrent duplicate returns <c>null</c> as a backstop. Returns the created row on a fresh report.
    /// </summary>
    Task<HiddenPlaceSuppression?> RecordReportAsync(
        int userId, string recommendedPlaceId, string placeId, string name, string reason);

    /// <summary>
    /// Applies ONE user's report against a Google-sourced place (no recommended-place submission).
    /// Storage is one row per (user, place): a report creates a new row with
    /// <c>RecommendedPlaceId = null</c>. The service layer owns the duplicate-report decision
    /// (<see cref="ExistsAsync"/>, V-11); the null return here is a concurrency backstop.
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
