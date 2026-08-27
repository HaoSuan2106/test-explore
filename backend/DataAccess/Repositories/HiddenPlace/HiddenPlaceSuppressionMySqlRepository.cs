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
                .AnyAsync(s => s.PlaceId == placeId);

            if (already)
            {
                return;
            }

            _context.HiddenPlaceSuppressions.Add(new HiddenPlaceSuppression
            {
                PlaceId = placeId,
                Name = name,
                Reason = reason,
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
}
