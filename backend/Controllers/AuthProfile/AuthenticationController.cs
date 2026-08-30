using ExploreMy.Api.Application.AuthProfile.Facade;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DTOs.AuthProfile;
using Microsoft.AspNetCore.Mvc;
using Org.BouncyCastle.Asn1.Ocsp;

namespace ExploreMy.Api.Controllers.AuthProfile;

[ApiController]
[Route("api/auth")]
public class AuthenticationController : ControllerBase
{
    private readonly IAuthProfileService _authProfileService;
    private readonly ILogger<AuthenticationController> _logger;

    public AuthenticationController(
        IAuthProfileService authProfileService,
        ILogger<AuthenticationController> logger)
    {
        _authProfileService = authProfileService;
        _logger = logger;
    }

    [HttpPost("login")]
    public async Task<ActionResult<LoginResponseDto>> Login([FromBody] LoginRequestDto request)
    {
        try
        {
            var result = await _authProfileService.LoginAsync(request);
            return Ok(result);
        }
        catch (AuthenticationException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during login for {Email}.", request.Email);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<LoginResponseDto>> Refresh([FromBody] RefreshTokenRequestDto request)
    {
        try
        {
            var result = await _authProfileService.RefreshTokenAsync(request);
            return Ok(result);
        }
        catch (AuthenticationException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during token refresh.");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] LogoutRequestDto request)
    {
        try
        {
            await _authProfileService.LogoutAsync(request);
            return Ok(new { message = "Logged out." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during logout.");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("register")]
    public async Task<ActionResult<RegisterResponseDto>> Register([FromBody] RegisterRequestDto request)
    {
        try
        {
            var result = await _authProfileService.RegisterAsync(request);
            return StatusCode(StatusCodes.Status201Created, result);
        }
        catch (ConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during registration for {Email}.", request.Email);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("verify-email")]
    public async Task<ActionResult<LoginResponseDto>> VerifyEmail([FromBody] VerifyEmailRequestDto request)
    {
        try
        {
            var result = await _authProfileService.VerifyEmailAsync(request);
            return Ok(result);
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
            _logger.LogError(ex, "Unexpected error during email verification for {Email}.", request.Email);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("resend-verification")]
    public async Task<IActionResult> ResendVerification([FromBody] ResendVerificationRequestDto request)
    {
        try
        {
            await _authProfileService.ResendVerificationAsync(request);
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
            _logger.LogError(ex, "Unexpected error during verification resend for {Email}.", request.Email);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    /// UC102 FR102-13/FR102-14 — signed-out password reset, step 1.
    /// Always answers 200 so the response cannot be used to discover which
    /// email addresses have accounts.
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequestDto request)
    {
        try
        {
            await _authProfileService.RequestPasswordResetAsync(request);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during password reset request for {Email}.", request.Email);
        }

        return Ok(new
        {
            message = "If an account exists for that email, a reset code has been sent."
        });
    }

    /// FR102-17 — signed-out password reset, step 2: check the emailed code
    /// before the user is allowed to type a new password (FR102-18).
    [HttpPost("forgot-password/verify")]
    public async Task<IActionResult> VerifyForgotPasswordCode(
        [FromBody] VerifyForgotPasswordCodeRequestDto request)
    {
        try
        {
            await _authProfileService.VerifyPasswordResetCodeAsync(request);
            return Ok(new { message = "Verification code accepted." });
        }
        catch (AuthenticationException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error verifying reset code for {Email}.", request.Email);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    /// FR102-19..FR102-22 — signed-out password reset, step 3.
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequestDto request)
    {
        try
        {
            await _authProfileService.ResetPasswordAsync(request);
            return Ok(new { message = "Password updated successfully." });
        }
        catch (AuthenticationException ex)
        {
            return Unauthorized(new { message = ex.Message });
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
            _logger.LogError(ex, "Unexpected error resetting password for {Email}.", request.Email);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }
}