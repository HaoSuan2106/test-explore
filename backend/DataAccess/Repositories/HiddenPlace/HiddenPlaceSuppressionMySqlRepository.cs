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
            var ids = await _context.HiddenPlaceSuppressions
                .AsNoTracking()
                .Select(s => s.PlaceId)
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

    public async Task SuppressAsync(string placeId, string? name, string? reason, int reportCount)
    {
        try
        {
            var already = await _context.HiddenPlaceSuppressions
                .AnyAsync(s => s.PlaceId == placeId && s.UserId == 0);

            if (already)
            {
                return;
            }

            _context.HiddenPlaceSuppressions.Add(new HiddenPlaceSuppression
            {
                UserId = 0,
                PlaceId = placeId,
                Name = name ?? string.Empty,
                Reason = reason ?? string.Empty,
                ReportCount = reportCount,
                SuppressedAt = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();

            _logger.LogInformation(
                "Suppressed place {PlaceId} ({Name}) after {ReportCount} report(s): {Reason}",
                placeId, name, reportCount, reason);
        }
        catch (DbUpdateException ex)
        {
            // The unique index doing its job - two reports crossed the threshold at the same moment.
            // The place is suppressed either way, which is the only outcome anyone cares about.
            _logger.LogWarning(ex, "Place {PlaceId} was suppressed concurrently; nothing to do.", placeId);
        }
    }

    public async Task<HiddenPlaceSuppression?> GetByRecommendedPlaceIdAsync(string recommendedPlaceId)
    {
        return await _context.HiddenPlaceSuppressions
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.RecommendedPlaceId == recommendedPlaceId);
    }

    public async Task<bool> HasUserReportedRecommendedPlaceAsync(int userId, string recommendedPlaceId)
    {
        return await _context.HiddenPlaceSuppressions
            .AsNoTracking()
            .AnyAsync(s => s.UserId == userId && s.RecommendedPlaceId == recommendedPlaceId);
    }

    /// <summary>
    /// ONE USER + ONE PLACE = ONE ACTIVE REPORT.
    /// Place Report is NOT a toggle and NOT an anonymous aggregate.
    /// When the same user has already reported the same place, returns <c>null</c>
    /// (the caller — the service layer — throws a <c>ValidationException</c>).
    /// Otherwise inserts a new row with <c>ReportCount = 1</c>.
    /// </summary>
    public async Task<HiddenPlaceSuppression?> RecordReportAsync(
        int userId, string recommendedPlaceId, string placeId, string name, string reason)
    {
        // Duplicate check: already a row for this (user, place)?
        var existing = await _context.HiddenPlaceSuppressions
            .AnyAsync(s => s.UserId == userId && s.PlaceId == placeId);

        if (existing)
        {
            _logger.LogInformation(
                "User {UserId} has already reported place {PlaceId} (recommended {RecommendedPlaceId}); duplicate rejected.",
                userId, placeId, recommendedPlaceId);
            return null;
        }

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
    /// ONE USER + ONE GOOGLE PLACE = ONE ACTIVE REPORT.
    /// Same-user repeats are rejected (returns <c>null</c>).
    /// Google-sourced rows carry <c>RecommendedPlaceId = null</c>.
    /// </summary>
    public async Task<HiddenPlaceSuppression?> RecordGooglePlaceReportAsync(
        int userId, string placeId, string name, string reason)
    {
        // Duplicate check: already a row for this (user, place) with recommended_place_id = null?
        var existing = await _context.HiddenPlaceSuppressions
            .AnyAsync(s => s.UserId == userId && s.PlaceId == placeId && s.RecommendedPlaceId == null);

        if (existing)
        {
            _logger.LogInformation(
                "User {UserId} has already reported Google place {PlaceId}; duplicate rejected.",
                userId, placeId);
            return null;
        }

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