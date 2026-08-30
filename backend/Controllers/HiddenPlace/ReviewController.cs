using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using ExploreMy.Api.Application.HiddenPlace.Review;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DTOs.HiddenPlace;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ExploreMy.Api.Controllers.HiddenPlace;

[ApiController]
[Route("api/hidden-places/reviews")]
public class ReviewController : ControllerBase
{
    private readonly IReviewService _reviewService;
    private readonly ILogger<ReviewController> _logger;

    public ReviewController(
        IReviewService reviewService,
        ILogger<ReviewController> logger)
    {
        _reviewService = reviewService;
        _logger = logger;
    }

    // ============================================================
    // GET REVIEW BY ID
    // ============================================================

    [HttpGet("{reviewId:long}")]
    public async Task<ActionResult<HiddenPlaceReviewDto>> GetById(
        long reviewId)
    {
        try
        {
            var result = await _reviewService.GetByIdAsync(reviewId);

            if (result is null)
                return NotFound(new { message = "Review not found." });

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error getting review {ReviewId}.",
                reviewId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // GET REVIEWS FOR GOOGLE PLACE
    // ============================================================

    [HttpGet("google/{googlePlaceId}")]
    public async Task<ActionResult<List<HiddenPlaceReviewDto>>>
        GetByGooglePlaceId(string googlePlaceId)
    {
        try
        {
            var result =
                await _reviewService.GetByGooglePlaceIdAsync(
                    googlePlaceId);

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error getting reviews for Google place {GooglePlaceId}.",
                googlePlaceId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // GET REVIEWS FOR SYSTEM / RECOMMENDED PLACE
    // ============================================================

    [HttpGet("recommend/{recommendPlaceId}")]
    public async Task<ActionResult<List<HiddenPlaceReviewDto>>>
        GetByRecommendPlaceId(string recommendPlaceId)
    {
        try
        {
            var result =
                await _reviewService.GetByRecommendPlaceIdAsync(
                    recommendPlaceId);

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error getting reviews for recommended place {RecommendPlaceId}.",
                recommendPlaceId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // GET CURRENT USER'S REVIEW - GOOGLE PLACE
    // ============================================================

    [Authorize]
    [HttpGet("google/{googlePlaceId}/mine")]
    public async Task<ActionResult<HiddenPlaceReviewDto>>
        GetMyGooglePlaceReview(string googlePlaceId)
    {
        try
        {
            var userId = GetCurrentUserId();

            var result =
                await _reviewService.GetUserReviewForGooglePlaceAsync(
                    userId,
                    googlePlaceId);

            if (result is null)
                return NotFound(new { message = "Review not found." });

            return Ok(result);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error getting user's Google place review.");

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // GET CURRENT USER'S REVIEW - SYSTEM PLACE
    // ============================================================

    [Authorize]
    [HttpGet("recommend/{recommendPlaceId}/mine")]
    public async Task<ActionResult<HiddenPlaceReviewDto>>
        GetMyRecommendPlaceReview(string recommendPlaceId)
    {
        try
        {
            var userId = GetCurrentUserId();

            var result =
                await _reviewService.GetUserReviewForRecommendPlaceAsync(
                    userId,
                    recommendPlaceId);

            if (result is null)
                return NotFound(new { message = "Review not found." });

            return Ok(result);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error getting user's recommended place review.");

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // CREATE REVIEW
    // ============================================================

    [Authorize]
    [HttpPost]
    public async Task<ActionResult<HiddenPlaceReviewDto>> Create(
        [FromBody] CreateHiddenPlaceReviewRequestDto request)
    {
        try
        {
            var userId = GetCurrentUserId();

            var result =
                await _reviewService.CreateAsync(
                    userId,
                    request);

            return StatusCode(
                StatusCodes.Status201Created,
                result);
        }
        catch (ConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error creating review.");

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // UPLOAD REVIEW PHOTOS
    // ============================================================

    [Authorize]
    [HttpPost("{reviewId:long}/photos")]
    [RequestSizeLimit(25 * 1024 * 1024)]
    public async Task<ActionResult<List<HiddenPlaceReviewPhotoDto>>> UploadPhotos(
        long reviewId,
        [FromForm] List<IFormFile> files)
    {
        try
        {
            var userId = GetCurrentUserId();

            var result = await _reviewService.UploadPhotosAsync(
                userId,
                reviewId,
                files);

            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(
                StatusCodes.Status403Forbidden,
                new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error uploading photos for review {ReviewId}.",
                reviewId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // UPDATE REVIEW
    // ============================================================

    [Authorize]
    [HttpPut("{reviewId:long}")]
    public async Task<ActionResult<HiddenPlaceReviewDto>> Update(
        long reviewId,
        [FromBody] UpdateHiddenPlaceReviewRequestDto request)
    {
        try
        {
            var userId = GetCurrentUserId();

            var result =
                await _reviewService.UpdateAsync(
                    userId,
                    reviewId,
                    request);

            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(
                StatusCodes.Status403Forbidden,
                new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error updating review {ReviewId}.",
                reviewId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // DELETE REVIEW
    // ============================================================

    [Authorize]
    [HttpDelete("{reviewId:long}")]
    public async Task<IActionResult> Delete(long reviewId)
    {
        try
        {
            var userId = GetCurrentUserId();

            await _reviewService.DeleteAsync(
                userId,
                reviewId);

            return NoContent();
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(
                StatusCodes.Status403Forbidden,
                new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error deleting review {ReviewId}.",
                reviewId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // DELETE REVIEW PHOTO
    // ============================================================

    [Authorize]
    [HttpDelete("{reviewId:long}/photos/{reviewPhotoId:long}")]
    public async Task<IActionResult> DeletePhoto(
        long reviewId,
        long reviewPhotoId)
    {
        try
        {
            var userId = GetCurrentUserId();

            await _reviewService.DeletePhotoAsync(
                userId,
                reviewId,
                reviewPhotoId);

            return NoContent();
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(
                StatusCodes.Status403Forbidden,
                new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error deleting review photo {ReviewPhotoId} from review {ReviewId}.",
                reviewPhotoId,
                reviewId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // REPORT REVIEW
    // ============================================================

    [Authorize]
    [HttpPost("{reviewId:long}/report")]
    public async Task<IActionResult> Report(
        long reviewId,
        [FromBody] ReportReviewRequest request)
    {
        try
        {
            var userId = GetCurrentUserId();

            await _reviewService.ReportAsync(
                userId,
                reviewId,
                request.Reason);

            return Ok(new
            {
                message = "Review reported successfully."
            });
        }
        catch (ConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error reporting review {ReviewId}.",
                reviewId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    // ============================================================
    // GET CURRENT USER ID FROM JWT
    // ============================================================

    private int GetCurrentUserId()
    {
        var userIdClaim =
            User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue("sub");

        if (!int.TryParse(userIdClaim, out var userId))
        {
            throw new UnauthorizedAccessException(
                "Unable to determine current user.");
        }

        return userId;
    }
}