using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;

namespace ExploreMy.Api.DataAccess.Repositories.HiddenPlace;

public class HiddenPlaceSuppressionMySqlRepository : IHiddenPlaceSuppressionRepository
{
    private readonly MySqlDbContext _context;
    private readonly ILogger<HiddenPlaceSuppressionMySqlRepository> _logger;

    public HiddenPlaceSuppressionMySqlRepository(
        MySqlDbContext context, ILogger<HiddenPlaceSuppressionMySqlRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<HashSet<string>> GetSuppressedPlaceIdsAsync()
    {
        try
        {
            // Grouped and thresholded, NOT "every row in the table".
            //
            // Storage here is one row per (user, place) - a row means "this person reported this
            // place", not "this place is hidden". Selecting the ids raw made a SINGLE report remove a
            // place from everyone's map, which is both far too easy to abuse and flatly contradicts
            // HideThreshold, the number the report endpoint reports progress against and uses to
            // decide when a place is actually hidden.
            //
            // Summing ReportCount rather than counting rows: an ordinary user row carries 1, and the
            // legacy anonymous rows created before user_id existed carry their historical aggregate.
            // Counting rows would silently devalue those old aggregates to one report each.
            var ids = await _context.HiddenPlaceSuppressions
                .AsNoTracking()
                .GroupBy(s => s.PlaceId)
                .Where(g => g.Sum(s => s.ReportCount) >= RecommendedPlaceThresholds.HideThreshold)
                .Select(g => g.Key)
                .ToListAsync();

            return ids.ToHashSet(StringComparer.Ordinal);
        }
        catch (Exception ex)
        {
            // Fail OPEN, not closed. This list only ever removes places from a result set, so losing
            // it briefly means a reported place slips back into one search - annoying. Throwing would
            // mean nobody can search at all - much worse. The alternative (fail closed, hide
            // everything) is not on the table: an empty map is indistinguishable from a broken app.
            _logger.LogError(ex, "Could not read the suppression list; this search will not apply it.");
            return new HashSet<string>(StringComparer.Ordinal);
        }
    }

    public async Task<bool> HasUserReportedRecommendedPlaceAsync(int userId, string recommendedPlaceId)
    {
        return await _context.HiddenPlaceSuppressions
            .AsNoTracking()
            .AnyAsync(s => s.UserId == userId && s.RecommendedPlaceId == recommendedPlaceId);
    }

    public async Task<bool> ExistsAsync(int userId, string placeId)
    {
        return await _context.HiddenPlaceSuppressions
            .AsNoTracking()
            .AnyAsync(s => s.UserId == userId && s.PlaceId == placeId);
    }

    /// <summary>
    /// Applies ONE user's report against a recommended place (V-11). Storage is one row per
    /// (user, place): a report creates a new row with <c>ReportCount = 1</c>. Place Report is NOT
    /// a toggle — the "reject a duplicate report" business decision lives in the service layer,
    /// which calls <see cref="ExistsAsync"/> first. This method persists and surfaces the unique
    /// constraint only: a concurrent duplicate (UNIQUE(user_id, place_id)) returns <c>null</c> as
    /// a backstop. Returns the created row on a fresh report.
    /// </summary>
    public async Task<HiddenPlaceSuppression?> RecordReportAsync(
        int userId, string recommendedPlaceId, string placeId, string name, string reason)
    {
        var created = new HiddenPlaceSuppression
        {
            UserId = userId,
            PlaceId = placeId,
            RecommendedPlaceId = recommendedPlaceId,
            Name = name,
            Reason = reason,
            ReportCount = 1,
            SuppressedAt = DateTime.UtcNow,
        };
        _context.HiddenPlaceSuppressions.Add(created);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            // UNIQUE(user_id, place_id) caught a concurrent duplicate — treat as already reported.
            _logger.LogInformation(
                "Concurrent duplicate report by user {UserId} on place {PlaceId}; rejecting.",
                userId, placeId);
            return null;
        }

        _logger.LogInformation(
            "User {UserId} reported recommended place {RecommendedPlaceId} ({Name}): reason {Reason}.",
            userId, recommendedPlaceId, name, reason);
        return created;
    }

    /// <summary>
    /// Applies ONE user's report against a Google-sourced place (no recommended-place submission).
    /// Storage is one row per (user, place): a report creates a new row with
    /// <c>RecommendedPlaceId = null</c>. The service layer checks <see cref="ExistsAsync"/> for the
    /// duplicate-report business decision; the null return here is only a concurrency backstop.
    /// Returns the created row on a fresh report.
    /// </summary>
    public async Task<HiddenPlaceSuppression?> RecordGooglePlaceReportAsync(
        int userId, string placeId, string name, string reason)
    {
        var created = new HiddenPlaceSuppression
        {
            UserId = userId,
            PlaceId = placeId,
            RecommendedPlaceId = null,
            Name = name,
            Reason = reason,
            ReportCount = 1,
            SuppressedAt = DateTime.UtcNow,
        };
        _context.HiddenPlaceSuppressions.Add(created);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            _logger.LogInformation(
                "Concurrent duplicate report by user {UserId} on Google place {PlaceId}; rejecting.",
                userId, placeId);
            return null;
        }

        _logger.LogInformation(
            "User {UserId} reported Google place {PlaceId} ({Name}): reason {Reason}.",
            userId, placeId, name, reason);
        return created;
    }

    public async Task<Dictionary<string, int>> GetReportCountsByRecommendedPlaceIdsAsync(
        IReadOnlyCollection<string> recommendedPlaceIds)
    {
        if (recommendedPlaceIds is null || recommendedPlaceIds.Count == 0)
        {
            return new Dictionary<string, int>(StringComparer.Ordinal);
        }

        // With one row per (user, place) report, multiple rows may exist per recommended_place_id.
        // Group by recommended_place_id and sum ReportCount to get the total (each user row = 1,
        // legacy anonymous rows keep their historical count).
        return await _context.HiddenPlaceSuppressions
            .AsNoTracking()
            .Where(s => recommendedPlaceIds.Contains(s.RecommendedPlaceId!))
            .GroupBy(s => s.RecommendedPlaceId!)
            .Select(g => new { RecommendedPlaceId = g.Key, ReportCount = g.Sum(s => s.ReportCount) })
            .ToDictionaryAsync(k => k.RecommendedPlaceId, v => v.ReportCount, StringComparer.Ordinal);
    }

    public async Task<int> GetReportCountByPlaceIdAsync(string placeId)
    {
        return await _context.HiddenPlaceSuppressions
            .AsNoTracking()
            .Where(s => s.PlaceId == placeId)
            .SumAsync(s => s.ReportCount);
    }
}