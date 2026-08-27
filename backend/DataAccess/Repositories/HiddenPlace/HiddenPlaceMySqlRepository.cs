using Microsoft.EntityFrameworkCore;
using ExploreMy.Api.Persistence.DbContext;
using HiddenPlaceEntity = ExploreMy.Api.Domain.Entities.HiddenPlace;
using ExploreMy.Api.Domain.Entities;

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
    //private readonly MySqlDbContext _context;
    //private readonly ILogger<HiddenPlaceMySqlRepository> _logger;

    //public HiddenPlaceMySqlRepository(MySqlDbContext context, ILogger<HiddenPlaceMySqlRepository> logger)
    //{
    //    _context = context;
    //    _logger = logger;
    //}

    // ---------------- Recommended Places ----------------

    public async Task<List<RecommendedPlace>> GetBySubmitterAsync(int userId)
    {
        try
        {
            return await _context.RecommendedPlaces
                .Where(p => p.SubmitterId == userId)
                .Include(p => p.Verifications.Where(v => v.Status == RecommendedPlaceVerificationStatus.Active))
                .Include(p => p.Reports.Where(r => r.Status == RecommendedPlaceReportStatus.Active))
                .OrderByDescending(p => p.CreatedAt)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading recommended places of user {UserId}.", userId);
            throw;
        }
    }

    public async Task<List<RecommendedPlace>> GetPublishedPlacesAsync()
    {
        try
        {
            return await _context.RecommendedPlaces
                .Where(p => p.Status == RecommendedPlaceStatus.Verified)
                .Include(p => p.Verifications.Where(v => v.Status == RecommendedPlaceVerificationStatus.Active))
                .Include(p => p.Reports.Where(r => r.Status == RecommendedPlaceReportStatus.Active))
                .OrderByDescending(p => p.CreatedAt)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading published recommended places.");
            throw;
        }
    }

    public async Task<RecommendedPlace?> GetByIdAsync(string submissionId)
    {
        try
        {
            return await _context.RecommendedPlaces
                .Where(p => p.SubmissionId == submissionId)
                .Include(p => p.Submitter)
                .Include(p => p.Verifications.Where(v => v.Status == RecommendedPlaceVerificationStatus.Active))
                .Include(p => p.Reports.Where(r => r.Status == RecommendedPlaceReportStatus.Active))
                .FirstOrDefaultAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading recommended place {SubmissionId}.", submissionId);
            throw;
        }
    }

    public async Task<bool> ExistsByNameAndAddressAsync(string name, string address)
    {
        try
        {
            return await _context.RecommendedPlaces.AnyAsync(p =>
                p.Name == name
                && p.LocationAddress == address
                && p.Status != RecommendedPlaceStatus.Withdrawn);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking duplicate recommended place.");
            throw;
        }
    }

    /// <summary>
    /// True when a non-withdrawn recommended place has coordinates within
    /// [radiusMeters] of the given point (REQ502_5 proximity duplicate check).
    /// </summary>
    public async Task<bool> ExistsNearbyAsync(decimal latitude, decimal longitude, double radiusMeters)
    {
        try
        {
            var places = await _context.RecommendedPlaces
                .Where(p => p.Status != RecommendedPlaceStatus.Withdrawn
                            && p.Latitude != null
                            && p.Longitude != null)
                .Select(p => new { p.Latitude, p.Longitude })
                .ToListAsync();

            // Haversine distance in meters; any hit within the radius counts.
            return places.Any(p =>
                HaversineMeters((double)p.Latitude!, (double)p.Longitude!,
                    (double)latitude, (double)longitude) <= radiusMeters);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking nearby recommended place.");
            throw;
        }
    }

    private static double HaversineMeters(double lat1, double lon1, double lat2, double lon2)
    {
        const double earthRadiusM = 6371000.0;
        double ToRad(double deg) => deg * Math.PI / 180.0;

        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
                + Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2))
                * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return earthRadiusM * c;
    }

    public async Task CreatePlaceAsync(RecommendedPlace place)
    {
        try
        {
            place.CreatedAt = DateTime.UtcNow;
            place.UpdatedAt = place.CreatedAt;
            _context.RecommendedPlaces.Add(place);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating recommended place.");
            throw;
        }
    }

    public async Task UpdatePlaceAsync(RecommendedPlace place)
    {
        try
        {
            place.UpdatedAt = DateTime.UtcNow;
            _context.RecommendedPlaces.Update(place);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating recommended place {SubmissionId}.", place.SubmissionId);
            throw;
        }
    }

    // ---------------- Verifications (voting) ----------------

    public async Task<RecommendedPlaceVerification?> GetActiveVerificationAsync(string submissionId, int userId)
    {
        try
        {
            return await _context.RecommendedPlaceVerifications
                .FirstOrDefaultAsync(v => v.SubmissionId == submissionId
                                          && v.UserId == userId
                                          && v.Status == RecommendedPlaceVerificationStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading verification of user {UserId} for place {SubmissionId}.", userId, submissionId);
            throw;
        }
    }

    public async Task<RecommendedPlaceVerification?> GetAnyVerificationAsync(string submissionId, int userId)
    {
        try
        {
            return await _context.RecommendedPlaceVerifications
                .FirstOrDefaultAsync(v => v.SubmissionId == submissionId
                                          && v.UserId == userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading any verification of user {UserId} for place {SubmissionId}.", userId, submissionId);
            throw;
        }
    }

    public async Task CreateVerificationAsync(RecommendedPlaceVerification verification)
    {
        try
        {
            verification.CreatedAt = DateTime.UtcNow;
            _context.RecommendedPlaceVerifications.Add(verification);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating verification.");
            throw;
        }
    }

    public async Task UpdateVerificationAsync(RecommendedPlaceVerification verification)
    {
        try
        {
            _context.RecommendedPlaceVerifications.Update(verification);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating verification {VerificationId}.", verification.VerificationId);
            throw;
        }
    }

    public async Task<int> GetActiveVerificationCountAsync(string submissionId)
    {
        try
        {
            return await _context.RecommendedPlaceVerifications
                .CountAsync(v => v.SubmissionId == submissionId
                                 && v.Status == RecommendedPlaceVerificationStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while counting verifications for place {SubmissionId}.", submissionId);
            throw;
        }
    }

    // ---------------- Reports ----------------

    public async Task<RecommendedPlaceReport?> GetActiveReportAsync(string submissionId, int userId)
    {
        try
        {
            return await _context.RecommendedPlaceReports
                .FirstOrDefaultAsync(r => r.SubmissionId == submissionId
                                          && r.ReporterId == userId
                                          && r.Status == RecommendedPlaceReportStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading report of user {UserId} for place {SubmissionId}.", userId, submissionId);
            throw;
        }
    }

    public async Task CreateReportAsync(RecommendedPlaceReport report)
    {
        try
        {
            report.CreatedAt = DateTime.UtcNow;
            _context.RecommendedPlaceReports.Add(report);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating report.");
            throw;
        }
    }

    public async Task<int> GetActiveReportCountAsync(string submissionId)
    {
        try
        {
            return await _context.RecommendedPlaceReports
                .CountAsync(r => r.SubmissionId == submissionId
                                 && r.Status == RecommendedPlaceReportStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while counting reports for place {SubmissionId}.", submissionId);
            throw;
        }
    }
}