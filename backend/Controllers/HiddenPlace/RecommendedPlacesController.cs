using ExploreMy.Api.Application.HiddenPlace.Facade;
using ExploreMy.Api.Common.Helpers;
using ExploreMy.Api.DTOs.HiddenPlace;
using ExploreMy.Api.Domain.Entities;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using ExploreMy.Api.Common.Exceptions;
using Microsoft.AspNetCore.Authorization;

namespace ExploreMy.Api.Controllers.HiddenPlace;

[Route("api/recommended-places")]
[ApiController]
[Authorize]
public class RecommendedPlacesController : ControllerBase
{
    private readonly IHiddenPlaceService _hiddenPlaceService;
    private readonly ILogger<RecommendedPlacesController> _logger;

    public RecommendedPlacesController(IHiddenPlaceService hiddenPlaceService, ILogger<RecommendedPlacesController> logger)
    {
        _hiddenPlaceService = hiddenPlaceService;
        _logger = logger;
    }

    private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    // ============================================================
    // Discover — public listing of VERIFIED places (REQ502_20)
    // ============================================================

    // ============================================================
    // Primary Type options (sourced from hidden_place_cache — read-only)
    // ============================================================

    /// <summary>
    /// Distinct Primary Type options for the Recommend Place form, sourced from
    /// <c>hidden_place_cache.primary_type</c> (read-only; the cache is never written here).
    /// Example: GET /api/recommended-places/primary-types
    /// </summary>
    [HttpGet("primary-types")]
    public async Task<IActionResult> GetPrimaryTypes()
    {
        try
        {
            var types = await _hiddenPlaceService.GetPrimaryTypeOptionsAsync();
            return Ok(types);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching Primary Type options.");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Retrieve verified recommended places for public discovery.</summary>
    [HttpGet("discover")]
    public async Task<IActionResult> GetPublishedPlaces()
    {
        try
        {
            var places = await _hiddenPlaceService.GetPublishedPlacesAsync();
            return Ok(places);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching published recommended places.");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // My Recommended Places
    // ============================================================

    /// <summary>Retrieve the authenticated user's recommended places (My Recommended Places).</summary>
    [HttpGet]
    public async Task<IActionResult> GetMyPlaces()
    {
        try
        {
            var places = await _hiddenPlaceService.GetMyPlacesAsync(CurrentUserId);
            return Ok(places);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching recommended places for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Retrieve details of a single recommended place (Place Details).</summary>
    [HttpGet("{submissionId}")]
    public async Task<IActionResult> GetPlaceDetails(string submissionId)
    {
        try
        {
            var details = await _hiddenPlaceService.GetPlaceDetailsAsync(CurrentUserId, submissionId);
            return Ok(details);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching recommended place {SubmissionId} for user {UserId}.", submissionId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Submit a new recommended place (Recommend Place).</summary>
    [HttpPost]
    public async Task<IActionResult> SubmitPlace([FromBody] SubmitRecommendedPlaceRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid place data.", errors = ModelState });
        }

        try
        {
            var result = await _hiddenPlaceService.SubmitPlaceAsync(CurrentUserId, request);
            return CreatedAtAction(nameof(GetPlaceDetails), new { submissionId = result.SubmissionId }, result);
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error submitting recommended place for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>
    /// Update an existing recommended place (Edit Recommendation). Updates BOTH the
    /// canonical place row (<c>recommended_places</c>) and the submission timestamp
    /// (<c>place_submissions.updated_at</c>) in one transaction.
    /// </summary>
    [HttpPut("{submissionId}")]
    public async Task<IActionResult> UpdatePlace(string submissionId, [FromBody] SubmitRecommendedPlaceRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid place data.", errors = ModelState });
        }

        try
        {
            var result = await _hiddenPlaceService.UpdateRecommendationAsync(CurrentUserId, submissionId, request);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error updating recommended place {SubmissionId} for user {UserId}.", submissionId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Photos (upload before submit; returned public URLs go in photo_json)
    // ============================================================

    [HttpPost("images/upload")]
    [RequestSizeLimit(ImageUploadPolicy.MaxSizeBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = ImageUploadPolicy.MaxSizeBytes)]
    public async Task<IActionResult> UploadPlaceImage(IFormFile? file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "No image was uploaded." });
        }

        if (file.Length > ImageUploadPolicy.MaxSizeBytes)
        {
            return BadRequest(new { message = "Image exceeds the 5 MB size limit." });
        }

        if (!ImageUploadPolicy.IsAllowedImageType(file.ContentType, ImageUploadPolicy.RecommendedPlaceImageContentTypes))
        {
            return BadRequest(new { message = "Unsupported image type. Allowed: JPEG, PNG, WebP." });
        }

        try
        {
            await using var stream = file.OpenReadStream();
            var url = await _hiddenPlaceService.UploadPlaceImageAsync(CurrentUserId, stream, file.FileName, file.ContentType);
            return Ok(new { imageUrl = url });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error uploading recommended-place image for user {UserId}.", CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Community Voting (verifications)
    // ============================================================    /// <summary>Verify a recommended place (community voting) or withdraw a previous verification.</summary>
    [HttpPost("{submissionId}/verifications")]
    public async Task<IActionResult> ToggleVerification(string submissionId, [FromBody] ToggleVerificationRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid verification data.", errors = ModelState });
        }

        try
        {
            var result = await _hiddenPlaceService.ToggleVerificationAsync(CurrentUserId, submissionId, request.Verify);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error toggling verification on place {SubmissionId} for user {UserId}.", submissionId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Recommendation Withdrawal (OWNER ONLY) — status: place_submissions
    // ============================================================

    /// <summary>
    /// OWNER WITHDRAWAL — a COMPLETELY SEPARATE function from place reporting.
    /// The submitter/owner moves their own recommendation to WITHDRAWN
    /// (place_submissions.status). Only the owner may withdraw; a non-owner
    /// is rejected with 403 Forbidden.
    /// </summary>
    [HttpPost("{submissionId}/withdraw")]
    public async Task<IActionResult> WithdrawRecommendation(string submissionId)
    {
        try
        {
            var result = await _hiddenPlaceService.WithdrawRecommendationAsync(CurrentUserId, submissionId);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error withdrawing recommendation {SubmissionId} for user {UserId}.", submissionId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Place Reports (anonymous) — storage: hidden_place_suppression
    // ============================================================

    /// <summary>Supported PLACE report reasons (NOT post-report reasons).</summary>
    [HttpGet("report-reasons")]
    public IActionResult GetReportReasons()
        => Ok(new { reasons = PlaceReportReasons.All });

    /// <summary>
    /// Returns whether the CURRENT authenticated user has already reported the given place.
    /// Accepts BOTH place identities: a recommended-place submission GUID
    /// (<c>place_submissions.submission_id</c>, resolved to the canonical
    /// <c>recommend_place_id</c> like the report endpoint) OR a Google-sourced
    /// <c>place_id</c> (checked directly against <c>hidden_place_suppression.place_id</c>).
    ///
    /// The Report Place button reads this to show "Reported" (disabled) instead of
    /// "Report Place" when the current user already has an active report.
    /// </summary>
    [HttpGet("{placeId}/report-status")]
    public async Task<IActionResult> GetPlaceReportStatus(string placeId)
    {
        try
        {
            var result = await _hiddenPlaceService.GetPlaceReportStatusAsync(CurrentUserId, placeId);
            return Ok(result);
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetPlaceReportStatus UNEXPECTED ERROR. PlaceId={PlaceId}, UserId={UserId}", placeId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>
    /// Records a PLACE report against a recommended place. The report is persisted in
    /// <c>hidden_place_suppression</c> as ONE row per (user, place) — the reporter's identity
    /// (<see cref="CurrentUserId"/>, from the authenticated JWT) is always stored. A repeated
    /// report by the SAME user on the SAME place is rejected with <c>409 Conflict</c> (the client
    /// reflects the already-reported state instead of re-prompting). Once the total of distinct
    /// user reports reaches <see cref="RecommendedPlaceThresholds.HideThreshold"/> the submission
    /// moves to <c>REPORTED_CLOSED</c> and is hidden from community voting.
    /// </summary>
    [HttpPost("{submissionId}/reports")]
    public async Task<IActionResult> ReportPlace(
    string submissionId,
    [FromBody] ReportPlaceRequestDto request)
    {
        _logger.LogInformation(
            "ReportPlace START. SubmissionId={SubmissionId}, UserId={UserId}, Reason={Reason}",
            submissionId,
            CurrentUserId,
            request?.Reason);

        if (!ModelState.IsValid)
        {
            _logger.LogWarning(
                "ReportPlace INVALID MODEL. SubmissionId={SubmissionId}, UserId={UserId}, Errors={Errors}",
                submissionId,
                CurrentUserId,
                ModelState);

            return BadRequest(new
            {
                message = "Invalid report data.",
                errors = ModelState
            });
        }

        try
        {
            _logger.LogInformation(
                "ReportPlace calling HiddenPlaceService.ReportPlaceAsync. SubmissionId={SubmissionId}, UserId={UserId}",
                submissionId,
                CurrentUserId);

            var result = await _hiddenPlaceService.ReportPlaceAsync(
                CurrentUserId,
                submissionId,
                request.Reason);

            _logger.LogInformation(
                "ReportPlace SUCCESS. SubmissionId={SubmissionId}, UserId={UserId}, Result={Result}",
                submissionId,
                CurrentUserId,
                result);

            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            _logger.LogWarning(
                ex,
                "ReportPlace NOT FOUND. SubmissionId={SubmissionId}, UserId={UserId}, Message={Message}",
                submissionId,
                CurrentUserId,
                ex.Message);

            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            _logger.LogWarning(
                ex,
                "ReportPlace FORBIDDEN. SubmissionId={SubmissionId}, UserId={UserId}, Message={Message}",
                submissionId,
                CurrentUserId,
                ex.Message);

            return StatusCode(
                StatusCodes.Status403Forbidden,
                new { message = ex.Message });
        }
        catch (ConflictException ex)
        {
            _logger.LogWarning(
                ex,
                "ReportPlace CONFLICT / DUPLICATE. SubmissionId={SubmissionId}, UserId={UserId}, Message={Message}",
                submissionId,
                CurrentUserId,
                ex.Message);

            return StatusCode(
                StatusCodes.Status409Conflict,
                new { message = ex.Message });
        }
        catch (ValidationException ex)
        {
            _logger.LogWarning(
                ex,
                "ReportPlace VALIDATION ERROR. SubmissionId={SubmissionId}, UserId={UserId}, Message={Message}",
                submissionId,
                CurrentUserId,
                ex.Message);

            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "ReportPlace UNEXPECTED ERROR. SubmissionId={SubmissionId}, UserId={UserId}, Reason={Reason}",
                submissionId,
                CurrentUserId,
                request?.Reason);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }
}
