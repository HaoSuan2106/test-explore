using Microsoft.EntityFrameworkCore;
using ExploreMy.Api.Persistence.DbContext;
using ExploreMy.Api.Common.Helpers;
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

    /// <summary>
    /// Distinct non-empty <c>primary_type</c> values from <c>hidden_place_cache</c>, used only as a
    /// read-only option source for the Recommend New Place Primary Type selector.
    /// </summary>
    public async Task<List<string>> GetDistinctPrimaryTypesAsync()
    {
        try
        {
            return await _context.HiddenPlaces
                .Where(p => p.PrimaryType != null && p.PrimaryType.Trim() != "")
                .Select(p => p.PrimaryType.Trim())
                .Distinct()
                .OrderBy(t => t)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error reading distinct primary types from hidden-place cache.");
            throw;
        }
    }
    public async Task<HiddenPlaceEntity?> GetGooglePlaceByIdAsync(string placeId)
    {
        try
        {
            return await _context.HiddenPlaces
                .AsNoTracking()
                .Where(p => p.PlaceId == placeId)
                .FirstOrDefaultAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while looking up Google place {PlaceId}.", placeId);
            throw;
        }
    }

    // ---------------- Recommended Places (normalized: canonical place + submission) ----------------

    public async Task<List<PlaceSubmission>> GetBySubmitterAsync(int userId)
    {
        try
        {
            return await _context.PlaceSubmissions
                .Where(p => p.SubmitterId == userId)
                .Include(p => p.Place)
                .Include(p => p.Verifications.Where(v => v.Status == RecommendedPlaceVerificationStatus.Active))
                .OrderByDescending(p => p.CreatedAt)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading recommended places of user {UserId}.", userId);
            throw;
        }
    }

    public async Task<List<PlaceSubmission>> GetPublishedPlacesAsync(bool includeUnderVoting = false)
    {
        try
        {
            // Listed positively rather than as "not withdrawn, not reported": a status added later
            // then has to be named here to become visible, which is the safe direction to fail.
            return await _context.PlaceSubmissions
                .Where(p => p.Status == RecommendedPlaceStatus.Verified
                    || (includeUnderVoting && p.Status == RecommendedPlaceStatus.UnderVoting))
                .Include(p => p.Place)
                .Include(p => p.Verifications.Where(v => v.Status == RecommendedPlaceVerificationStatus.Active))
                .OrderByDescending(p => p.CreatedAt)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading published recommended places.");
            throw;
        }
    }

    public async Task<PlaceSubmission?> GetByIdAsync(string submissionId)
    {
        try
        {
            return await _context.PlaceSubmissions
                .Where(p => p.SubmissionId == submissionId)
                .Include(p => p.Submitter)
                .Include(p => p.Place)
                .Include(p => p.Verifications.Where(v => v.Status == RecommendedPlaceVerificationStatus.Active))
                .FirstOrDefaultAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading recommended place {SubmissionId}.", submissionId);
            throw;
        }
    }

    public async Task<bool> ExistsByNameAsync(string name, IEnumerable<string>? excludedStatuses = null)
    {
        try
        {
            var excluded = (excludedStatuses ?? []).ToHashSet();
            // The canonical place is checked together with its submissions: a place only
            // counts as a duplicate when at least one of its submissions is not excluded
            // (the caller decides which statuses do not block a new recommendation).
            return await _context.RecommendPlaces.AnyAsync(p =>
                p.Name == name
                && p.Submissions.Any(s => !excluded.Contains(s.Status)));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking duplicate recommended place.");
            throw;
        }
    }

    /// <summary>
    /// True when a recommended submission with a canonical place with coordinates
    /// within [radiusMeters] of the given point is NOT in any excluded status
    /// (REQ502_5 proximity duplicate check).
    /// </summary>
    public async Task<bool> ExistsNearbyAsync(decimal latitude, decimal longitude, double radiusMeters, IEnumerable<string>? excludedStatuses = null)
    {
        try
        {
            var excluded = (excludedStatuses ?? []).ToHashSet();
            var places = await _context.RecommendPlaces
                .Where(p => p.Submissions.Any(s => !excluded.Contains(s.Status)))
                .Select(p => new { p.Latitude, p.Longitude })
                .ToListAsync();

            // Haversine distance in meters; any hit within the radius counts.
            return places.Any(p =>
                GeoDistance.HaversineMeters(p.Latitude, p.Longitude,
                    (double)latitude, (double)longitude) <= radiusMeters);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while checking nearby recommended place.");
            throw;
        }
    }

    /// <summary>
    /// Inserts the canonical place row first, then the submission row referencing it, in a single
    /// transaction (PART K: place before submission).
    /// Contract: place_submissions.created_at/updated_at store Malaysia wall-clock via the explicit
    /// Asia/Kuala_Lumpur timezone (MalaysiaTime.Now) — never the server OS timezone and never a
    /// hard-coded +8h offset. Both fields are stamped from the SAME captured instant.
    /// </summary>
    public async Task CreateSubmissionAsync(RecommendPlace place, PlaceSubmission submission)
    {
        try
        {
            var now = MalaysiaTime.Now;
            submission.CreatedAt = now;
            submission.UpdatedAt = now;
            _context.RecommendPlaces.Add(place);
            submission.RecommendPlaceId = place.RecommendPlaceId;
            _context.PlaceSubmissions.Add(submission);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating recommended place.");
            throw;
        }
    }

    public async Task UpdateSubmissionAsync(PlaceSubmission submission)
    {
        try
        {
            // Malaysia wall-clock via explicit Asia/Kuala_Lumpur; created_at is untouched by EF.
            submission.UpdatedAt = MalaysiaTime.Now;
            _context.PlaceSubmissions.Update(submission);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating recommended place {SubmissionId}.", submission.SubmissionId);
            throw;
        }
    }

    /// <summary>
    /// Updates BOTH halves of a recommendation atomically in one transaction:
    /// the canonical place data (<c>recommended_places</c>) and the submission
    /// timestamp (<c>place_submissions.updated_at</c>). This is the UPDATE half of
    /// the recommendation lifecycle — without it an edit would refresh only one
    /// table and the two would drift apart.
    /// </summary>
    public async Task UpdateRecommendationAsync(RecommendPlace place, PlaceSubmission submission)
    {
        try
        {
            // Malaysia wall-clock via explicit Asia/Kuala_Lumpur; created_at is untouched by EF.
            submission.UpdatedAt = MalaysiaTime.Now;
            _context.RecommendPlaces.Update(place);
            _context.PlaceSubmissions.Update(submission);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating recommendation {SubmissionId}.", submission.SubmissionId);
            throw;
        }
    }

    // ---------------- Verifications (voting) ----------------

    public async Task<PlaceSubmissionVerification?> GetActiveVerificationAsync(string submissionId, int userId)
    {
        try
        {
            return await _context.PlaceSubmissionVerifications
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

    public async Task<PlaceSubmissionVerification?> GetAnyVerificationAsync(string submissionId, int userId)
    {
        try
        {
            return await _context.PlaceSubmissionVerifications
                .FirstOrDefaultAsync(v => v.SubmissionId == submissionId
                                          && v.UserId == userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while loading any verification of user {UserId} for place {SubmissionId}.", userId, submissionId);
            throw;
        }
    }

    public async Task CreateVerificationAsync(PlaceSubmissionVerification verification)
    {
        try
        {
            verification.CreatedAt = DateTime.UtcNow;
            _context.PlaceSubmissionVerifications.Add(verification);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while creating verification.");
            throw;
        }
    }

    public async Task UpdateVerificationAsync(PlaceSubmissionVerification verification)
    {
        try
        {
            _context.PlaceSubmissionVerifications.Update(verification);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while updating verification {VerificationId}.", verification.VerificationId);
            throw;
        }
    }

    public async Task DeleteVerificationAsync(PlaceSubmissionVerification verification)
    {
        try
        {
            _context.PlaceSubmissionVerifications.Remove(verification);
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while deleting verification {VerificationId}.", verification.VerificationId);
            throw;
        }
    }

    public async Task<int> GetActiveVerificationCountAsync(string submissionId)
    {
        try
        {
            return await _context.PlaceSubmissionVerifications
                .CountAsync(v => v.SubmissionId == submissionId
                                 && v.Status == RecommendedPlaceVerificationStatus.Active);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database error while counting verifications for place {SubmissionId}.", submissionId);
            throw;
        }
    }
}