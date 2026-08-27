using ExploreMy.Api.Application.HiddenPlace.Facade;
using ExploreMy.Api.DTOs.HiddenPlace;
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

    /// <summary>Withdraw one of the authenticated user's own recommended places.</summary>
    [HttpPost("{submissionId}/withdraw")]
    public async Task<IActionResult> WithdrawPlace(string submissionId)
    {
        try
        {
            var result = await _hiddenPlaceService.WithdrawPlaceAsync(CurrentUserId, submissionId);
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
            _logger.LogError(ex, "Unexpected error withdrawing recommended place {SubmissionId} for user {UserId}.", submissionId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    /// <summary>Retrieve the predefined report reasons for recommended places.</summary>
    [HttpGet("report-reasons")]
    public IActionResult GetReportReasons()
    {
        try
        {
            var reasons = _hiddenPlaceService.GetReportReasons();
            return Ok(new { reasons });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching recommended-place report reasons.");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // Community Voting (verifications)
    // ============================================================

    /// <summary>Verify a recommended place (community voting) or withdraw a previous verification.</summary>
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
    // Reports
    // ============================================================

    /// <summary>Report a recommended place with a predefined reason.</summary>
    [HttpPost("{submissionId}/reports")]
    public async Task<IActionResult> ReportPlace(string submissionId, [FromBody] ReportRecommendedPlaceRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Invalid report data.", errors = ModelState });
        }

        try
        {
            var result = await _hiddenPlaceService.ReportPlaceAsync(CurrentUserId, submissionId, request.Reason);
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
            _logger.LogError(ex, "Unexpected error reporting place {SubmissionId} for user {UserId}.", submissionId, CurrentUserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }
}
