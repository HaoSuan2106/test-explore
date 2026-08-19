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
}