using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;

namespace ExploreMy.Api.DataAccess.Repositories.PlacePhotos;

public class PlacePhotoMySqlRepository : IPlacePhotoRepository
{
    private readonly MySqlDbContext _context;
    private readonly ILogger<PlacePhotoMySqlRepository> _logger;

    public PlacePhotoMySqlRepository(MySqlDbContext context, ILogger<PlacePhotoMySqlRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<Dictionary<string, PlacePhoto>> GetByPlaceIdsAsync(IReadOnlyCollection<string> placeIds)
    {
        if (placeIds.Count == 0)
        {
            return new Dictionary<string, PlacePhoto>();
        }

        // AsNoTracking: these rows are read to build a response and never modified, so there is no
        // reason to pay for change tracking on up to a few hundred of them per search.
        var rows = await _context.PlacePhotos
            .AsNoTracking()
            .Where(p => placeIds.Contains(p.PlaceId))
            .ToListAsync();

        // Group before ToDictionary rather than keying directly: place_id is uniquely indexed, so a
        // duplicate should be impossible, but ToDictionary would throw and take a whole search down
        // with it if one ever existed. Reading is not the place to discover a constraint problem.
        return rows
            .GroupBy(p => p.PlaceId)
            .ToDictionary(g => g.Key, g => g.First());
    }

    public async Task AddRangeAsync(IReadOnlyCollection<PlacePhoto> photos)
    {
        if (photos.Count == 0)
        {
            return;
        }

        _context.PlacePhotos.AddRange(photos);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
        {
            // Almost certainly the unique index on place_id: another request copied the same place's
            // photo between this one's read and its write. The other request's row is just as good,
            // and the image is already sitting in the bucket either way, so there is nothing to fix -
            // log it and let the search return normally rather than 500 over a duplicate.
            _logger.LogWarning(
                ex, "Could not persist {Count} place photo(s) - likely a concurrent insert of the same place.",
                photos.Count);

            // Detach the failed inserts so this scoped DbContext is not left holding entities that
            // will be retried (and fail again) on the next SaveChangesAsync in the same request.
            foreach (var photo in photos)
            {
                _context.Entry(photo).State = EntityState.Detached;
            }
        }
    }
}
