using System.Security.Claims;
using ExploreMy.Api.Application.AuthProfile.ManageProfile;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DTOs.AuthProfile;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace explore_my_backend.Controllers.AuthProfile;

[Route("api/profile")]
[ApiController]
[Authorize]
public class ProfileController : ControllerBase
{

    private readonly IManageProfileService _manageProfileService;
    private readonly ILogger<ProfileController> _logger;

    public ProfileController(IManageProfileService manageProfileService, ILogger<ProfileController> logger)
    {
        _manageProfileService = manageProfileService;
        _logger = logger;
    }

    private static readonly HashSet<string> AllowedPictureContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg", "image/png", "image/webp",
    };

    private const long MaxPictureSizeBytes = 5 * 1024 * 1024;

    [HttpGet]
    public async Task<IActionResult> GetProfile()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            var profile = await _manageProfileService.GetProfileAsync(userId);
            return Ok(profile);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching profile for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPut]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            var profile = await _manageProfileService.UpdateProfileAsync(userId, request);
            return Ok(profile);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error updating profile for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("email/request-change")]
    public async Task<IActionResult> RequestEmailChange([FromBody] RequestEmailChangeRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            await _manageProfileService.RequestEmailChangeAsync(userId, request);
            return Ok(new { message = "Verification code sent." });
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error requesting email change for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("email/verify-change")]
    public async Task<IActionResult> VerifyEmailChange([FromBody] VerifyEmailChangeRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            var profile = await _manageProfileService.VerifyEmailChangeAsync(userId, request);
            return Ok(profile);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (AuthenticationException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (ConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error verifying email change for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("password/reset-code")]
    public async Task<IActionResult> RequestPasswordResetCode()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            await _manageProfileService.RequestPasswordResetCodeAsync(userId);
            return Ok(new { message = "Verification code sent." });
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error requesting password reset code for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("password/reset-code/verify")]
    public async Task<IActionResult> VerifyPasswordResetCode([FromBody] VerifyPasswordResetCodeRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            await _manageProfileService.VerifyPasswordResetCodeAsync(userId, request);
            return Ok(new { message = "Code verified." });
        }
        catch (AuthenticationException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error verifying password reset code for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("picture")]
    [RequestSizeLimit(MaxPictureSizeBytes)]
    public async Task<IActionResult> UpdateProfilePicture(IFormFile? file)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "No file was uploaded." });
        }

        if (file.Length > MaxPictureSizeBytes)
        {
            return BadRequest(new { message = "File exceeds the 5MB size limit." });
        }

        if (!AllowedPictureContentTypes.Contains(file.ContentType))
        {
            return BadRequest(new { message = "Unsupported file type. Allowed: jpeg, png, webp." });
        }

        try
        {
            await using var stream = file.OpenReadStream();
            var profile = await _manageProfileService.UpdateProfilePictureAsync(userId, stream, file.FileName, file.ContentType);
            return Ok(profile);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error updating profile picture for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpDelete("picture")]
    public async Task<IActionResult> RemoveProfilePicture()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            var profile = await _manageProfileService.RemoveProfilePictureAsync(userId);
            return Ok(profile);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error removing profile picture for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

}
