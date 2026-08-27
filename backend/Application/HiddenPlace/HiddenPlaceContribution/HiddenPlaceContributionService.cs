using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DataAccess.Repositories.HiddenPlace;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.HiddenPlace;

namespace ExploreMy.Api.Application.HiddenPlace.HiddenPlaceContribution;

public class HiddenPlaceContributionService : IHiddenPlaceContributionService
{
    private readonly IHiddenPlaceRepository _repository;
    private readonly ILogger<HiddenPlaceContributionService> _logger;

    public HiddenPlaceContributionService(IHiddenPlaceRepository repository, ILogger<HiddenPlaceContributionService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<List<RecommendedPlaceSummaryDto>> GetMyPlacesAsync(int currentUserId)
    {
        var places = await _repository.GetBySubmitterAsync(currentUserId);
        return places
            .OrderByDescending(p => p.CreatedAt)
            .Select(ToSummaryDto)
            .ToList();
    }

    public async Task<RecommendedPlaceDetailsDto> GetPlaceDetailsAsync(int currentUserId, string submissionId)
    {
        var place = await _repository.GetByIdAsync(submissionId)
            ?? throw new NotFoundException($"Recommended place '{submissionId}' was not found.");

        var isCurrentUserSubmitter = place.SubmitterId == currentUserId;

        return new RecommendedPlaceDetailsDto
        {
            SubmissionId = place.SubmissionId,
            Name = place.Name,
            LocationAddress = place.LocationAddress,
            Category = place.Category,
            Description = place.Description,
            Status = place.Status,
            VerificationCount = place.Verifications.Count,
            ReportCount = place.Reports.Count,
            RequiredVerifications = RecommendedPlaceThresholds.RequiredVerifications,
            CreatedAt = place.CreatedAt,
            UpdatedAt = place.UpdatedAt,
            SubmitterId = isCurrentUserSubmitter ? place.SubmitterId : 0,
            // L-05: recommender identity stays anonymous to everyone except the
            // submitter themselves (who sees their own name on their own screen).
            SubmitterName = isCurrentUserSubmitter ? (place.Submitter?.Username ?? "Unknown") : string.Empty,
            IsCurrentUserSubmitter = isCurrentUserSubmitter,
            IsVerifiedByCurrentUser = place.Verifications.Any(v => v.UserId == currentUserId),
            IsReportedByCurrentUser = place.Reports.Any(r => r.ReporterId == currentUserId),
            Reports = place.Reports
                .Select(r => new RecommendedPlaceReportDto
                {
                    ReportId = r.ReportId,
                    SubmissionId = r.SubmissionId,
                    ReporterId = r.ReporterId,
                    Reason = r.Reason,
                    Status = r.Status,
                    CreatedAt = r.CreatedAt,
                })
                .ToList(),
        };
    }

    public async Task<SubmitRecommendedPlaceResponseDto> SubmitPlaceAsync(int currentUserId, SubmitRecommendedPlaceRequestDto request)
    {
        var name = request.Name.Trim();
        var address = request.LocationAddress.Trim();
        var category = request.Category.Trim();
        var description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();

        if (string.IsNullOrWhiteSpace(name))
            throw new ValidationException("Place name is required.");
        if (string.IsNullOrWhiteSpace(description))
            throw new ValidationException("Place description is required.");
        if (string.IsNullOrWhiteSpace(address))
            throw new ValidationException("Location address is required.");
        if (string.IsNullOrWhiteSpace(category))
            throw new ValidationException("Category is required.");
        if (name.Length > 150)
            throw new ValidationException("Place name must not exceed 150 characters.");
        if (address.Length > 250)
            throw new ValidationException("Location address must not exceed 250 characters.");
        // L-11: only the predefined categories are accepted.
        if (!RecommendedPlaceCategories.Contains(category))
            throw new ValidationException($"Category '{category}' is not supported. Please select one of the provided categories.");
        if (category.Length > 50)
            throw new ValidationException("Category must not exceed 50 characters.");
        if (description?.Length > 500)
            throw new ValidationException("Description must not exceed 500 characters.");

        // REQ502_1/3: geographic coordinates are required and must be valid ranges.
        if (request.Latitude is null || request.Longitude is null)
            throw new ValidationException("Geographic coordinates (latitude and longitude) are required.");
        if (request.Latitude < -90m || request.Latitude > 90m)
            throw new ValidationException("Latitude must be between -90 and 90.");
        if (request.Longitude < -180m || request.Longitude > 180m)
            throw new ValidationException("Longitude must be between -180 and 180.");

        // Duplicate prevention (REQ502_5): same name + address → reject
        var isDuplicate = await _repository.ExistsByNameAndAddressAsync(name, address);
        if (isDuplicate)
            throw new ValidationException("This place has already been recommended. Please check your submissions.");

        // Duplicate prevention (REQ502_5): coordinates within proximity radius
        // (e.g. <100 m) of an existing non-withdrawn place → reject.
        var isNearby = await _repository.ExistsNearbyAsync(
            request.Latitude.Value, request.Longitude.Value, RecommendedPlaceThresholds.ProximityRadiusMeters);
        if (isNearby)
            throw new ValidationException("A place has already been recommended near these coordinates. Please check your submissions.");

        var place = new RecommendedPlace
        {
            SubmissionId = Guid.NewGuid().ToString(),
            SubmitterId = currentUserId,
            Name = name,
            LocationAddress = address,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Category = category,
            Description = description,
            Status = RecommendedPlaceStatus.UnderVoting,
        };

        await _repository.CreatePlaceAsync(place);

        _logger.LogInformation("User {UserId} submitted recommended place {SubmissionId}.", currentUserId, place.SubmissionId);
        return new SubmitRecommendedPlaceResponseDto
        {
            SubmissionId = place.SubmissionId,
            Message = "Your recommendation is now under community voting.",
        };
    }

    public async Task<WithdrawRecommendedPlaceResponseDto> WithdrawPlaceAsync(int currentUserId, string submissionId)
    {
        var place = await _repository.GetByIdAsync(submissionId)
            ?? throw new NotFoundException($"Recommended place '{submissionId}' was not found.");

        if (place.SubmitterId != currentUserId)
            throw new ForbiddenException("You can only withdraw your own recommendations.");
        if (place.Status == RecommendedPlaceStatus.Withdrawn)
            throw new ValidationException("This recommendation has already been withdrawn.");
        if (place.Status == RecommendedPlaceStatus.Verified)
            throw new ValidationException("Verified recommendations cannot be withdrawn.");

        place.Status = RecommendedPlaceStatus.Withdrawn;
        await _repository.UpdatePlaceAsync(place);

        _logger.LogInformation("User {UserId} withdrew recommended place {SubmissionId}.", currentUserId, submissionId);
        return new WithdrawRecommendedPlaceResponseDto
        {
            SubmissionId = place.SubmissionId,
            Status = place.Status,
            Message = "Your recommendation has been withdrawn and removed from community voting.",
        };
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
                await _repository.CreateVerificationAsync(new RecommendedPlaceVerification
                {
                    VerificationId = Guid.NewGuid().ToString(),
                    SubmissionId = submissionId,
                    UserId = currentUserId,
                    Status = RecommendedPlaceVerificationStatus.Active,
                });
            }

            var count = await _repository.GetActiveVerificationCountAsync(submissionId);
            if (count >= RecommendedPlaceThresholds.RequiredVerifications)
            {
                place.Status = RecommendedPlaceStatus.Verified;
                await _repository.UpdatePlaceAsync(place);
            }

            _logger.LogInformation("User {UserId} verified recommended place {SubmissionId} (count {Count}).", currentUserId, submissionId, count);
            return new ToggleVerificationResponseDto
            {
                SubmissionId = submissionId,
                IsVerified = true,
                VerificationCount = count,
                PlaceStatus = place.Status,
                Message = place.Status == RecommendedPlaceStatus.Verified
                    ? "Congratulations! This place has reached the required verifications and is now Verified."
                    : "Thank you for verifying this place.",
            };
        }

        // Withdraw verification
        if (existing == null)
            throw new ValidationException("You have not verified this place.");

        existing.Status = RecommendedPlaceVerificationStatus.Withdrawn;
        await _repository.UpdateVerificationAsync(existing);
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

    public async Task<ReportRecommendedPlaceResponseDto> ReportPlaceAsync(int currentUserId, string submissionId, string reason)
    {
        var place = await _repository.GetByIdAsync(submissionId)
            ?? throw new NotFoundException($"Recommended place '{submissionId}' was not found.");

        if (place.SubmitterId == currentUserId)
            throw new ForbiddenException("You cannot report your own recommended place.");

        if (place.Status != RecommendedPlaceStatus.UnderVoting)
            throw new ValidationException($"This place cannot be reported in its current state (status: {place.Status}).");

        var trimmedReason = reason.Trim();
        if (string.IsNullOrWhiteSpace(trimmedReason))
            throw new ValidationException("Report reason is required.");
        if (!RecommendedPlaceReportReasons.All.Contains(trimmedReason))
            throw new ValidationException("The selected report reason is not valid.");

        var existing = await _repository.GetActiveReportAsync(submissionId, currentUserId);
        if (existing != null)
            throw new ValidationException("You have already reported this place.");

        // D5: reports are terminal — there is no withdrawal and no reactivation.
        var report = new RecommendedPlaceReport
        {
            ReportId = Guid.NewGuid().ToString(),
            SubmissionId = submissionId,
            ReporterId = currentUserId,
            Reason = trimmedReason,
            Status = RecommendedPlaceReportStatus.Active,
        };

        await _repository.CreateReportAsync(report);
        var reportId = report.ReportId;

        var count = await _repository.GetActiveReportCountAsync(submissionId);
        if (count >= RecommendedPlaceThresholds.HideThreshold)
        {
            place.Status = RecommendedPlaceStatus.ReportedClosed;
            await _repository.UpdatePlaceAsync(place);
        }

        _logger.LogInformation("User {UserId} reported recommended place {SubmissionId} (count {Count}).", currentUserId, submissionId, count);
        return new ReportRecommendedPlaceResponseDto
        {
            ReportId = reportId,
            SubmissionId = submissionId,
            ReportCount = count,
            PlaceStatus = place.Status,
            Message = count >= RecommendedPlaceThresholds.HideThreshold
                ? "This place has been removed from public view after receiving too many reports."
                : "Thank you. Your report has been recorded.",
        };
    }

    public IReadOnlyList<string> GetReportReasons() => RecommendedPlaceReportReasons.All;

    private static RecommendedPlaceSummaryDto ToSummaryDto(RecommendedPlace p) => new()
    {
        SubmissionId = p.SubmissionId,
        Name = p.Name,
        LocationAddress = p.LocationAddress,
        Latitude = p.Latitude,
        Longitude = p.Longitude,
        Category = p.Category,
        Description = p.Description,
        Status = p.Status,
        VerificationCount = p.Verifications.Count,
        ReportCount = p.Reports.Count,
        RequiredVerifications = RecommendedPlaceThresholds.RequiredVerifications,
        CreatedAt = p.CreatedAt,
        UpdatedAt = p.UpdatedAt,
    };
}