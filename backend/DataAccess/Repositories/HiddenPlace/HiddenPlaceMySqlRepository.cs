using Microsoft.EntityFrameworkCore;
using ExploreMy.Api.Persistence.DbContext;
using HiddenPlaceEntity = ExploreMy.Api.Domain.Entities.HiddenPlace;

namespace ExploreMy.Api.DataAccess.Repositories.HiddenPlace;

public class HiddenPlaceMySqlRepository : IHiddenPlaceRepository
{
    private readonly MySqlDbContext _context;
    private readonly ILogger<HiddenPlaceMySqlRepository> _logger;

    public HiddenPlaceMySqlRepository(MySqlDbContext context, ILogger<HiddenPlaceMySqlRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<Dictionary<string, List<HiddenPlaceEntity>>> GetFreshBucketsAsync(
        IReadOnlyCollection<string> cacheGridKeys, DateTime minFetchedAtUtc)
    {
        if (cacheGridKeys.Count == 0)
        {
            return new Dictionary<string, List<HiddenPlaceEntity>>();
        }

        try
        {
            var rows = await _context.HiddenPlaces
                .Where(p => cacheGridKeys.Contains(p.CacheGridKey))
                .ToListAsync();

            return rows
                .GroupBy(p => p.CacheGridKey)
                // Every row in a bucket is stamped with the same FetchedAtUtc by ReplaceBucketsAsync,
                // so checking the first row's timestamp is enough to judge the whole bucket's freshness.
                .Where(g => g.First().FetchedAtUtc >= minFetchedAtUtc)
                .ToDictionary(g => g.Key, g => g.ToList());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error reading hidden-place cache buckets.");
            throw;
        }
    }

    public async Task ReplaceBucketsAsync(
        IReadOnlyDictionary<string, List<HiddenPlaceEntity>> placesByBucketKey, DateTime fetchedAtUtc)
    {
        if (placesByBucketKey.Count == 0)
        {
            return;
        }

        try
        {
            var bucketKeys = placesByBucketKey.Keys.ToList();

            var existing = await _context.HiddenPlaces
                .Where(p => bucketKeys.Contains(p.CacheGridKey))
                .ToListAsync();
            _context.HiddenPlaces.RemoveRange(existing);

            foreach (var (bucketKey, places) in placesByBucketKey)
            {
                foreach (var place in places)
                {
                    place.CacheGridKey = bucketKey;
                    place.FetchedAtUtc = fetchedAtUtc;
                }
                await _context.HiddenPlaces.AddRangeAsync(places);
            }

            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error writing hidden-place cache buckets.");
            throw;
        }
    }
}
