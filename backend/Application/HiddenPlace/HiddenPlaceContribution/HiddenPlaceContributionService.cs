using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using Microsoft.Extensions.Options;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.HiddenPlaceContribution;

public class HiddenPlaceContributionService : IHiddenPlaceContributionService
{
    private readonly IHiddenPlaceRepository _repository;
    private readonly IHiddenPlaceSuppressionRepository _suppressionRepository;
    private readonly IStorageClient _storageClient;
    private readonly ILogger<HiddenPlaceContributionService> _logger;
    private readonly SupabaseSettings _supabase;

    public HiddenPlaceContributionService(
        IHiddenPlaceRepository repository,
        IHiddenPlaceSuppressionRepository suppressionRepository,
        IStorageClient storageClient,
        ILogger<HiddenPlaceContributionService> logger,
        IOptions<SupabaseSettings> supabase)
    {
        _repository = repository;
        _suppressionRepository = suppressionRepository;
        _storageClient = storageClient;
        _logger = logger;
        _supabase = supabase.Value;
    }

    /// <summary>
    /// Uploads a place photo to storage and returns its public URL. Uploads into
    /// the dedicated <c>recommended-place-images</c> bucket. Because photos are
    /// selected before the submission is created (Step 1 flow), the submission id
    /// does not exist yet, so the object path is scoped per user with a unique
    /// file name. The returned public URL is later persisted in photo_json.
    /// </summary>
    public async Task<string> UploadPlaceImageAsync(int currentUserId, Stream fileStream, string fileName, string contentType)
    {
        var bucket = _supabase.RecommendedPlaceImageBucket;
        var extension = Path.GetExtension(fileName);
        var path = $"recommended-places/{currentUserId}/{Guid.NewGuid()}{extension}";
        var url = await _storageClient.UploadToBucketAsync(bucket, path, fileStream, contentType);
        _logger.LogInformation("User {UserId} uploaded recommended-place image {Path}.", currentUserId, path);
        return url;
    }

    public async Task<List<RecommendedPlaceSummaryDto>> GetMyPlacesAsync(int currentUserId)
    {
        var places = await _repository.GetBySubmitterAsync(currentUserId);
        var reportCounts = await _suppressionRepository
            .GetReportCountsByRecommendedPlaceIdsAsync(places.Select(p => p.RecommendPlaceId).ToList());
        return places
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => ToSummaryDto(p, reportCounts))
            .ToList();
    }

    /// <summary>
    /// List recommended places that reached the VERIFIED status and are publicly viewable.
    /// Published places are a Contribution concern (submission lifecycle, status gates,
    /// verifications), so the listing lives here.
    /// </summary>
    public async Task<List<RecommendedPlaceSummaryDto>> GetPublishedPlacesAsync()
    {
        var places = await _repository.GetPublishedPlacesAsync();

        _logger.LogInformation("Loaded {Count} published recommended places.", places.Count);
        return places
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => ToSummaryDto(p))
            .ToList();
    }

    public async Task<RecommendedPlaceDetailsDto> GetPlaceDetailsAsync(int currentUserId, string submissionId)
    {
        var place = await _repository.GetByIdAsync(submissionId)
            ?? throw new NotFoundException($"Recommended place '{submissionId}' was not found.");

        var isCurrentUserSubmitter = place.SubmitterId == currentUserId;
        var reportCounts = await _suppressionRepository
            .GetReportCountsByRecommendedPlaceIdsAsync([place.RecommendPlaceId]);
        // Place Report rows store the CANONICAL recommend_place id (not the URL submission id), so
        // the per-user "already reported" lookup uses place.RecommendPlaceId — same id the report
        // endpoint persists (see ReportPlaceAsync identifier-mapping comment).
        var isReportedByCurrentUser = await _suppressionRepository
            .HasUserReportedRecommendedPlaceAsync(currentUserId, place.RecommendPlaceId);

        return new RecommendedPlaceDetailsDto
        {
            SubmissionId = place.SubmissionId,
            Name = place.Place!.Name,
            Latitude = (decimal)place.Place.Latitude,
            Longitude = (decimal)place.Place.Longitude,
            PrimaryType = place.Place.PrimaryType,
            Description = place.Place.Description,
            PriceLevel = place.Place!.PriceLevel,
            BusinessStatus = place.Place.BusinessStatus,
            PhotosJson = place.Place.PhotosJson,
            Status = place.Status,
            VerificationCount = place.Verifications.Count,
            ReportCount = reportCounts.TryGetValue(place.RecommendPlaceId, out var c) ? c : 0,
            RequiredVerifications = RecommendedPlaceThresholds.RequiredVerifications,
            CreatedAt = place.CreatedAt,
            UpdatedAt = place.UpdatedAt,
            SubmitterId = isCurrentUserSubmitter ? place.SubmitterId : 0,
            // L-05: recommender identity stays anonymous to everyone except the
            // submitter themselves (who sees their own name on their own screen).
            SubmitterName = isCurrentUserSubmitter ? (place.Submitter?.Username ?? "Unknown") : string.Empty,
            IsCurrentUserSubmitter = isCurrentUserSubmitter,
            IsVerifiedByCurrentUser = place.Verifications.Any(v => v.UserId == currentUserId),
            IsReportedByCurrentUser = isReportedByCurrentUser,
        };
    }

    public async Task<SubmitRecommendedPlaceResponseDto> SubmitPlaceAsync(int currentUserId, SubmitRecommendedPlaceRequestDto request)
    {
        var name = request.Name.Trim();
        var primaryType = request.PrimaryType.Trim();
        var description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();

        if (string.IsNullOrWhiteSpace(name))
            throw new ValidationException("Place name is required.");
        // L-05/DB alignment: description and price_level are nullable in the schema
        // (latest_v2.sql: description TEXT NULL, price_level INT NULL), so they are
        // optional at every layer — the UI, the API and the database agree.
        if (string.IsNullOrWhiteSpace(primaryType))
            throw new ValidationException("Primary Type is required.");
        if (name.Length > 150)
            throw new ValidationException("Place name must not exceed 150 characters.");
        // L-11 replaced: accepted Primary Type values are sourced dynamically from
        // hidden_place_cache.primary_type (read-only) — no hard-coded list. This keeps
        // the selector in the app in lock-step with the values the cache actually holds.
        var availablePrimaryTypes = await _repository.GetDistinctPrimaryTypesAsync();
        if (!availablePrimaryTypes.Contains(primaryType, StringComparer.OrdinalIgnoreCase))
            throw new ValidationException($"Primary Type '{primaryType}' is not supported. Please select one of the available Primary Types.");
        if (primaryType.Length > 100)
            throw new ValidationException("Primary Type must not exceed 100 characters.");
        if (description?.Length > 500)
            throw new ValidationException("Description must not exceed 500 characters.");

        // Price level is optional (0-4 when provided); the schema column is nullable.
        if (request.PriceLevel is < 0 or > 4)
            throw new ValidationException("Price level must be between 0 and 4.");

        // Business status is a closed set; the server is the final authority,
        // never the frontend dropdown alone. Missing → OPERATIONAL (backwards compatible).
        var businessStatus = string.IsNullOrWhiteSpace(request.BusinessStatus)
            ? BusinessStatus.Operational
            : request.BusinessStatus.Trim();
        if (!BusinessStatus.IsAllowed(businessStatus))
            throw new ValidationException($"Business status '{businessStatus}' is not supported. Allowed: {string.Join(", ", BusinessStatus.Allowed)}.");

        // Photos must be public image URLs previously returned by the upload
        // endpoint (bucket references) — never local device paths or base64.
        var photoRefs = (request.PhotosJson ?? new List<string>())
            .Where(p => !string.IsNullOrWhiteSpace(p))
            .Select(p => p.Trim())
            .ToList();
        if (photoRefs.Count > 3)
            throw new ValidationException("A place can have at most 3 photos.");
        foreach (var photo in photoRefs)
        {
            if (!Uri.TryCreate(photo, UriKind.Absolute, out var uri)
                || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
                throw new ValidationException("Photo references must be valid public image URLs.");
        }
        var photosJson = photoRefs.Count == 0 ? null : System.Text.Json.JsonSerializer.Serialize(photoRefs);

        // REQ502_1/3: geographic coordinates are required and must be valid ranges.
        if (request.Latitude is null || request.Longitude is null)
            throw new ValidationException("Geographic coordinates (latitude and longitude) are required.");
        if (request.Latitude < -90m || request.Latitude > 90m)
            throw new ValidationException("Latitude must be between -90 and 90.");
        if (request.Longitude < -180m || request.Longitude > 180m)
            throw new ValidationException("Longitude must be between -180 and 180.");

        // Duplicate prevention (REQ502_5): same name → reject. A withdrawn submission no
        // longer represents an existing place, so it does not block a new recommendation.
        var isDuplicate = await _repository.ExistsByNameAsync(name, [RecommendedPlaceStatus.Withdrawn]);
        if (isDuplicate)
            throw new ValidationException("This place has already been recommended. Please check your submissions.");

        // Duplicate prevention (REQ502_5): coordinates within proximity radius
        // (e.g. <100 m) of an existing non-withdrawn place → reject.
        var isNearby = await _repository.ExistsNearbyAsync(
            request.Latitude.Value, request.Longitude.Value, RecommendedPlaceThresholds.ProximityRadiusMeters,
            [RecommendedPlaceStatus.Withdrawn]);
        if (isNearby)
            throw new ValidationException("A place has already been recommended near these coordinates. Please check your submissions.");

        // Build canonical place and submission (PART K: place first, then submission, one transaction)
        var recommendPlaceId = "usr-" + Guid.NewGuid().ToString("N");
        var place = new RecommendPlace
        {
            RecommendPlaceId = recommendPlaceId,
            Name = name,
            PrimaryType = primaryType,
            Latitude = (double)request.Latitude.Value,
            Longitude = (double)request.Longitude.Value,
            // Price level is nullable in the schema (latest_v2.sql: price_level INT NULL).
            PriceLevel = request.PriceLevel,
            BusinessStatus = businessStatus,
            Description = description,
            PhotosJson = photosJson,
        };

        var submission = new PlaceSubmission
        {
            SubmissionId = Guid.NewGuid().ToString(),
            SubmitterId = currentUserId,
            RecommendPlaceId = recommendPlaceId,
            Status = RecommendedPlaceStatus.UnderVoting,
        };

        await _repository.CreateSubmissionAsync(place, submission);

        _logger.LogInformation("User {UserId} submitted recommended place {SubmissionId}.", currentUserId, submission.SubmissionId);
        return new SubmitRecommendedPlaceResponseDto
        {
            SubmissionId = submission.SubmissionId,
            Message = "Your recommendation is now under community voting.",
        };
    }

    /// <summary>
    /// Updates an existing recommendation in ONE transaction — BOTH the canonical
    /// place row (<c>recommended_places</c>) and the submission
    /// (<c>place_submissions.updated_at</c>). Ownership is enforced: only the
    /// submitter may edit, and only while the submission is still UNDER_VOTING
    /// (verified / withdrawn / report-closed submissions are immutable).
    ///
    /// This is the missing UPDATE half of the recommendation lifecycle: the
    /// submit path created both tables together, but no update path existed, so
    /// an edit could never keep recommended_places + place_submissions in sync.
    /// </summary>
    public async Task<SubmitRecommendedPlaceResponseDto> UpdateRecommendationAsync(
        int currentUserId, string submissionId, SubmitRecommendedPlaceRequestDto request)
    {
        var submission = await _repository.GetByIdAsync(submissionId)
            ?? throw new NotFoundException($"Recommended place '{submissionId}' was not found.");

        if (submission.SubmitterId != currentUserId)
            throw new ForbiddenException("You can only update your own recommendations.");
        if (submission.Status != RecommendedPlaceStatus.UnderVoting)
            throw new ValidationException($"Only submissions under community voting can be updated (current status: {submission.Status}).");

        var place = submission.Place
            ?? throw new NotFoundException($"Recommended place '{submissionId}' has no place data.");

        var name = request.Name.Trim();
        var primaryType = request.PrimaryType.Trim();
        var description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();

        if (string.IsNullOrWhiteSpace(name))
            throw new ValidationException("Place name is required.");
        if (string.IsNullOrWhiteSpace(primaryType))
            throw new ValidationException("Primary Type is required.");
        if (name.Length > 150)
            throw new ValidationException("Place name must not exceed 150 characters.");
        var availablePrimaryTypes = await _repository.GetDistinctPrimaryTypesAsync();
        if (!availablePrimaryTypes.Contains(primaryType, StringComparer.OrdinalIgnoreCase))
            throw new ValidationException($"Primary Type '{primaryType}' is not supported. Please select one of the available Primary Types.");
        if (primaryType.Length > 100)
            throw new ValidationException("Primary Type must not exceed 100 characters.");
        if (description?.Length > 500)
            throw new ValidationException("Description must not exceed 500 characters.");
        if (request.PriceLevel is < 0 or > 4)
            throw new ValidationException("Price level must be between 0 and 4.");

        var businessStatus = string.IsNullOrWhiteSpace(request.BusinessStatus)
            ? BusinessStatus.Operational
            : request.BusinessStatus.Trim();
        if (!BusinessStatus.IsAllowed(businessStatus))
            throw new ValidationException($"Business status '{businessStatus}' is not supported. Allowed: {string.Join(", ", BusinessStatus.Allowed)}.");

        var photoRefs = (request.PhotosJson ?? new List<string>())
            .Where(p => !string.IsNullOrWhiteSpace(p))
            .Select(p => p.Trim())
            .ToList();
        if (photoRefs.Count > 3)
            throw new ValidationException("A place can have at most 3 photos.");
        foreach (var photo in photoRefs)
        {
            if (!Uri.TryCreate(photo, UriKind.Absolute, out var uri)
                || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
                throw new ValidationException("Photo references must be valid public image URLs.");
        }
        var photosJson = photoRefs.Count == 0 ? null : System.Text.Json.JsonSerializer.Serialize(photoRefs);

        if (request.Latitude is null || request.Longitude is null)
            throw new ValidationException("Geographic coordinates (latitude and longitude) are required.");
        if (request.Latitude < -90m || request.Latitude > 90m)
            throw new ValidationException("Latitude must be between -90 and 90.");
        if (request.Longitude < -180m || request.Longitude > 180m)
            throw new ValidationException("Longitude must be between -180 and 180.");

        // Apply the edited canonical fields AND touch the submission timestamp in
        // one transaction — recommended_places + place_submissions stay in sync.
        place.Name = name;
        place.PrimaryType = primaryType;
        place.Description = description;
        place.Latitude = (double)request.Latitude.Value;
        place.Longitude = (double)request.Longitude.Value;
        place.PriceLevel = request.PriceLevel;
        place.BusinessStatus = businessStatus;
        place.PhotosJson = photosJson;

        await _repository.UpdateRecommendationAsync(place, submission);

        _logger.LogInformation("User {UserId} updated recommended place {SubmissionId}.", currentUserId, submissionId);
        return new SubmitRecommendedPlaceResponseDto
        {
            SubmissionId = submission.SubmissionId,
            Message = "Your recommendation has been updated.",
        };
    }

    /// <summary>
    /// Distinct Primary Type options for the Recommend Place form, read from
    /// <c>hidden_place_cache.primary_type</c> (read-only data source). The returned values
    /// are exactly what the cache holds — no hard-coded list, no invented fallbacks.
    /// </summary>
    public async Task<List<string>> GetPrimaryTypeOptionsAsync()
    {
        var types = await _repository.GetDistinctPrimaryTypesAsync();
        _logger.LogInformation("Loaded {Count} available Primary Type options from hidden_place_cache.", types.Count);
        return types;
    }

    public async Task<ToggleVerificationResponseDto> ToggleVerificationAsync(int currentUserId, string submissionId, bool verify)
    {
        var place = await _repository.GetByIdAsync(submissionId)
            ?? throw new NotFoundException($"Recommended place '{submissionId}' was not found.");

        if (place.Status != RecommendedPlaceStatus.UnderVoting)
            throw new ValidationException($"This place is not eligible for community verification (current status: {place.Status}).");

        // Submitter may not self-verify
        if (place.SubmitterId == currentUserId)
            throw new ForbiddenException("You cannot verify your own recommendation.");

        var existing = await _repository.GetActiveVerificationAsync(submissionId, currentUserId);

        if (verify)
        {
            if (existing != null)
                throw new ValidationException("You have already verified this place.");

            // A previous verification may exist in WITHDRAWN state (same user re-verifying after
            // withdrawing). Reactivate that row instead of inserting a new one — the database has
            // a unique constraint on (submission_id, user_id), so an INSERT would violate it.
            var prior = await _repository.GetAnyVerificationAsync(submissionId, currentUserId);
            if (prior is not null)
            {
                prior.Status = RecommendedPlaceVerificationStatus.Active;
                await _repository.UpdateVerificationAsync(prior);
            }
            else
            {
                await _repository.CreateVerificationAsync(new PlaceSubmissionVerification
                {
                    VerificationId = Guid.NewGuid().ToString(),
                    SubmissionId = submissionId,
                    UserId = currentUserId,
                    Status = RecommendedPlaceVerificationStatus.Active,
                });
            }

            var count = await _repository.GetActiveVerificationCountAsync(submissionId);

            // The vote that carries a submission over the line promotes it: UNDER_VOTING -> VERIFIED.
            //
            // This is what RequiredVerifications is FOR. Until now the constant was only ever read to
            // fill in "x of 5" on screen, and nothing acted on it, so a submission stayed UNDER_VOTING
            // no matter how many people agreed with it - it never entered the public discover listing
            // and its map pin stayed drawn as unverified forever.
            //
            // One-way on purpose. The guard at the top of this method rejects any vote once the status
            // leaves UNDER_VOTING, so a verified place cannot be un-verified by withdrawals afterwards.
            // A place that flickers between verified and not - as people change their minds, or a
            // single withdrawal drops it back to four - is worse than one that settles: this status is
            // what other users decide whether to trust.
            //
            // Reports are the way back, and they are handled separately: enough of them move the place
            // to REPORTED_CLOSED from VERIFIED as well as from UNDER_VOTING (see ReportPlaceAsync).
            if (count >= RecommendedPlaceThresholds.RequiredVerifications
                && place.Status == RecommendedPlaceStatus.UnderVoting)
            {
                place.Status = RecommendedPlaceStatus.Verified;
                await _repository.UpdateSubmissionAsync(place);

                _logger.LogInformation(
                    "Recommended place {SubmissionId} reached {Count} verifications and is now VERIFIED.",
                    submissionId, count);
            }

            _logger.LogInformation("User {UserId} verified recommended place {SubmissionId} (count {Count}).", currentUserId, submissionId, count);
            return new ToggleVerificationResponseDto
            {
                SubmissionId = submissionId,
                IsVerified = true,
                VerificationCount = count,

                // Read AFTER the promotion above, so the client is told the new status by the very
                // response to the vote that caused it rather than on some later refresh.
                PlaceStatus = place.Status,
                Message = "Thank you for verifying this place.",
            };
        }

        // Withdraw verification: delete only the current user's row.
        if (existing == null)
            throw new ValidationException("You have not verified this place.");

        await _repository.DeleteVerificationAsync(existing);
        var remaining = await _repository.GetActiveVerificationCountAsync(submissionId);

        _logger.LogInformation("User {UserId} withdrew verification for recommended place {SubmissionId}.", currentUserId, submissionId);
        return new ToggleVerificationResponseDto
        {
            SubmissionId = submissionId,
            IsVerified = false,
            VerificationCount = remaining,
            PlaceStatus = place.Status,
            Message = "Your verification has been withdrawn.",
        };
    }

    /// <summary>
    /// OWNER WITHDRAWAL — a COMPLETELY SEPARATE function from place reporting.
    ///
    /// The submitter/owner of a recommendation who no longer wants it to exist
    /// withdraws their own recommendation. This moves the submission to
    /// <c>WITHDRAWN</c> via the existing recommendation status mechanism
    /// (<c>place_submissions.status</c>) — it NEVER writes to
    /// <c>hidden_place_suppression</c> and is NOT a report.
    ///
    /// Ownership is enforced: only the submitter may withdraw. A non-owner is
    /// rejected with <see cref="ForbiddenException"/>.
    /// </summary>
    public async Task<SubmitRecommendedPlaceResponseDto> WithdrawRecommendationAsync(int currentUserId, string submissionId)
    {
        var submission = await _repository.GetByIdAsync(submissionId)
            ?? throw new NotFoundException($"Recommended place '{submissionId}' was not found.");

        if (submission.SubmitterId != currentUserId)
            throw new ForbiddenException("You can only withdraw your own recommendations.");

        if (submission.Status == RecommendedPlaceStatus.Withdrawn)
            throw new ValidationException("This recommendation has already been withdrawn.");

        // WITHDRAWN is the owner's own removal reason. A place already moved to
        // REPORTED_CLOSED by community reports is off the map for a different
        // reason; re-stamping it as WITHDRAWN would rewrite why it was removed.
        if (submission.Status == RecommendedPlaceStatus.ReportedClosed)
            throw new ValidationException("This recommendation has been removed after community reports and cannot be withdrawn.");

        submission.Status = RecommendedPlaceStatus.Withdrawn;
        await _repository.UpdateSubmissionAsync(submission);

        _logger.LogInformation("User {UserId} withdrew their own recommendation {SubmissionId}.", currentUserId, submissionId);
        return new SubmitRecommendedPlaceResponseDto
        {
            SubmissionId = submission.SubmissionId,
            Message = "Your recommendation has been withdrawn.",
        };
    }

    public async Task<ReportPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason)
    {
        if (string.IsNullOrWhiteSpace(reason) || reason.Length > 100)
            throw new ValidationException("A report reason (max 100 characters) is required.");

        var place = await _repository.GetByIdAsync(submissionId);

        // The Community Verification / Report Place UI is reachable from BOTH community
        // recommendations AND Google-sourced hidden places on the map. For a community
        // recommendation the identifier IS the submission id (GUID); for a Google place it is the
        // Google Place ID (e.g. "ChIJ..."), which has no place_submissions row. Resolve that
        // second case here so the same report flow writes hidden_place_suppression for both place
        // kinds (Google rows carry a NULL recommended_place_id - see the entity doc).
        if (place is null)
        {
            return await ReportGooglePlaceAsync(currentUserId, submissionId, reason);
        }

        // OWNER RESTRICTION (R9): the submitter/owner of a recommendation must NOT
        // report their own place. They use "Withdraw Recommendation" instead.
        if (place.SubmitterId == currentUserId)
            throw new ForbiddenException("You cannot report your own recommendation. Use 'Withdraw Recommendation' instead.");

        if (place.Status == RecommendedPlaceStatus.Withdrawn)
            throw new ValidationException("Withdrawn recommendations cannot be reported.");

        // ONE USER + ONE PLACE = ONE ACTIVE REPORT. The report is stored per (user, place):
        //
        // Identifier mapping (do NOT assume placeId == submissionId):
        //   submissionId (URL)  -> PlaceSubmission (this query)
        //   PlaceSubmission.RecommendPlaceId -> canonical recommend_place PK stored in
        //                                        hidden_place_suppression.recommended_place_id
        //   hidden_place_suppression.place_id  -> same canonical id (recommended places carry no
        //                                        Google place id)
        var canonicalPlaceId = place.RecommendPlaceId;

        // ONE USER + ONE PLACE = ONE ACTIVE REPORT. The business decision ("reject duplicate
        // with Conflict") lives in the service layer (V-11). The repository is responsible only
        // for persistence and unique-constraint surfacing (its null-return is a concurrency backstop).
        if (await _suppressionRepository.ExistsAsync(currentUserId, canonicalPlaceId))
            throw new ConflictException("You have already reported this place. You can only report a place once.");

        // RecordReportAsync returns null when a concurrent request hit the unique index first.
        var suppression = await _suppressionRepository.RecordReportAsync(
            currentUserId, canonicalPlaceId, canonicalPlaceId, place.Place!.Name, reason);

        if (suppression is null)
            throw new ConflictException("You have already reported this place. You can only report a place once.");

        // Threshold uses the TOTAL of distinct user reports for this place (sum of one-row-per-user
        // ReportCounts) - not the button-click count of this single request.
        var totalReports = await _suppressionRepository.GetReportCountByPlaceIdAsync(canonicalPlaceId);

        // Threshold: REPORTED_CLOSED hides the submission from community voting + publishing.
        //
        // VERIFIED counts here as well as UNDER_VOTING. Being verified is not immunity: a place can
        // pass verification and then close down, or turn out to be wrong, and that is exactly when
        // reports start arriving. Gating this on UNDER_VOTING alone left those submissions on the
        // map permanently - the reports were recorded and then acted on by nothing.
        //
        // WITHDRAWN and REPORTED_CLOSED are deliberately not listed: both are already off the map,
        // and re-stamping a withdrawn place as reported would rewrite why its author removed it.
        if (totalReports >= RecommendedPlaceThresholds.HideThreshold
            && (place.Status == RecommendedPlaceStatus.UnderVoting
                || place.Status == RecommendedPlaceStatus.Verified))
        {
            place.Status = RecommendedPlaceStatus.ReportedClosed;
            await _repository.UpdateSubmissionAsync(place);
        }

        _logger.LogInformation(
            "Report on submission {SubmissionId} (canonical {CanonicalPlaceId}) by user {UserId}: total now {ReportCount}.",
            submissionId, canonicalPlaceId, currentUserId, totalReports);

        var isHidden = totalReports >= RecommendedPlaceThresholds.HideThreshold;
        return new ReportPlaceResponseDto
        {
            SubmissionId = submissionId,
            ReportCount = totalReports,
            PlaceStatus = place.Status,
            Message = isHidden
                ? "This place has been hidden after enough community reports."
                : "Report recorded. Thank you for helping the community.",
        };
    }

    /// <summary>
    /// Records ONE user's report against a Google-sourced place (a place the user reached from the
    /// hidden-place map, which has no place_submissions row - its identifier is a Google Place ID
    /// such as "ChIJ..."). The report is persisted in <c>hidden_place_suppression</c> with
    /// <c>recommended_place_id = NULL</c> (Google-origin rows), one row per (user, place). Same-user
    /// repeats are rejected. There is no submission status to flip, so "hidden" means the
    /// suppression row itself now excludes the place from future searches.
    /// </summary>
    private async Task<ReportPlaceResponseDto> ReportGooglePlaceAsync(int currentUserId, string googlePlaceId, string reason)
    {
        var googlePlace = await _repository.GetGooglePlaceByIdAsync(googlePlaceId)
            ?? throw new NotFoundException($"Place '{googlePlaceId}' was not found.");

        // The duplicate-report policy (one report per user per place) is a service-layer
        // decision (V-11). The repository persists and surfaces the unique constraint; its
        // null-return below is only the concurrency backstop.
        if (await _suppressionRepository.ExistsAsync(currentUserId, googlePlace.PlaceId))
            throw new ConflictException("You have already reported this place. You can only report a place once.");

        var suppression = await _suppressionRepository.RecordGooglePlaceReportAsync(
            currentUserId, googlePlace.PlaceId, googlePlace.Name, reason);

        if (suppression is null)
            throw new ConflictException("You have already reported this place. You can only report a place once.");

        var totalReports = await _suppressionRepository.GetReportCountByPlaceIdAsync(googlePlace.PlaceId);

        var isHidden = totalReports >= RecommendedPlaceThresholds.HideThreshold;
        _logger.LogInformation(
            "Report on Google place {PlaceId} ({Name}) by user {UserId}: total now {ReportCount}.",
            googlePlace.PlaceId, googlePlace.Name, currentUserId, totalReports);

        return new ReportPlaceResponseDto
        {
            SubmissionId = googlePlace.PlaceId,
            ReportCount = totalReports,
            PlaceStatus = isHidden ? RecommendedPlaceStatus.ReportedClosed : RecommendedPlaceStatus.UnderVoting,
            Message = isHidden
                ? "This place has been hidden after enough community reports."
                : "Report recorded. Thank you for helping the community.",
        };
    }

    private static RecommendedPlaceSummaryDto ToSummaryDto(
        PlaceSubmission p, IReadOnlyDictionary<string, int>? reportCounts = null) => new()
    {
        SubmissionId = p.SubmissionId,
        Name = p.Place!.Name,
        Latitude = (decimal)p.Place.Latitude,
        Longitude = (decimal)p.Place.Longitude,
        PrimaryType = p.Place.PrimaryType,
        Description = p.Place.Description,
        PriceLevel = p.Place!.PriceLevel,
        BusinessStatus = p.Place.BusinessStatus,
        PhotosJson = p.Place.PhotosJson,
        Status = p.Status,
        VerificationCount = p.Verifications.Count,
        ReportCount = reportCounts is not null && reportCounts.TryGetValue(p.RecommendPlaceId, out var c) ? c : 0,
        RequiredVerifications = RecommendedPlaceThresholds.RequiredVerifications,
        CreatedAt = p.CreatedAt,
        UpdatedAt = p.UpdatedAt,
    };

    /// <inheritdoc/>
    public async Task<PlaceReportStatusResponseDto> GetPlaceReportStatusAsync(int currentUserId, string placeId)
    {
        if (string.IsNullOrWhiteSpace(placeId))
            throw new ValidationException("A place id is required.");

        // Same identifier resolution as ReportPlaceAsync: a recommended-place submission GUID
        // resolves to its canonical recommend_place_id; a Google-sourced place_id has no
        // submission row and is checked directly. hidden_place_suppression is the single
        // source of truth for "this user has already reported this place".
        var submission = await _repository.GetByIdAsync(placeId);
        var canonicalPlaceId = submission?.RecommendPlaceId ?? placeId;

        var isReported = await _suppressionRepository.ExistsAsync(currentUserId, canonicalPlaceId);
        return new PlaceReportStatusResponseDto { IsReportedByCurrentUser = isReported };
    }
}