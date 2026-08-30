using System.Security.Claims;
using ExploreMy.Api.Application.Community.Facade;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DTOs.Community;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ExploreMy.Api.Controllers.Community;

[Route("api/community")]
[ApiController]
[Authorize]
public class CommunityController : ControllerBase
{
    private readonly ICommunityService _communityService;
    private readonly ILogger<CommunityController> _logger;

    public CommunityController(ICommunityService communityService, ILogger<CommunityController> logger)
    {
        _communityService = communityService;
        _logger = logger;
    }

    private static readonly HashSet<string> AllowedImageContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg", "image/png", "image/webp",
    };

    // 10MB rather than 5MB: modern phone cameras routinely produce 5-8MB JPEGs even
    // after image_picker's client-side compression, so 5MB was rejecting real photos.
    private const long MaxImageSizeBytes = 10 * 1024 * 1024;

    // ---------------- View Community List / Join Community Group ----------------

    [HttpGet("joined")]
    public async Task<IActionResult> GetJoinedCommunities()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.GetJoinedCommunitiesAsync(userId);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching joined communities for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("browse")]
    public async Task<IActionResult> BrowseCommunities([FromBody] BrowseCommunitiesRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.BrowseCommunitiesAsync(request, userId);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error browsing communities for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpGet("{communityId:int}")]
    public async Task<IActionResult> GetCommunityDetail(int communityId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.GetCommunityDetailAsync(communityId, userId);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching community {CommunityId}.", communityId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("join")]
    public async Task<IActionResult> JoinCommunity([FromBody] JoinCommunityRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.JoinCommunityAsync(request.CommunityId, userId);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error joining community {CommunityId} for user {UserId}.", request.CommunityId, userId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("{communityId:int}/leave")]
    public async Task<IActionResult> LeaveCommunity(int communityId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.LeaveCommunityAsync(communityId, userId);
            return Ok(result);
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error leaving community {CommunityId} for user {UserId}.", communityId, userId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ---------------- Messages ----------------

    [HttpGet("{communityId:int}/messages")]
    public async Task<IActionResult> GetMessages(int communityId, [FromQuery] int take = 30, [FromQuery] int? beforeMessageId = null)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.GetMessagesAsync(communityId, userId, take, beforeMessageId);
            return Ok(result);
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching messages for community {CommunityId}.", communityId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("messages")]
    public async Task<IActionResult> SendMessage([FromBody] SendMessageRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.SendMessageAsync(request, userId);
            return StatusCode(StatusCodes.Status201Created, result);
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error sending a message to community {CommunityId}.", request.CommunityId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpDelete("messages/{messageId:int}")]
    public async Task<IActionResult> DeleteMessage(int messageId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var deleted = await _communityService.DeleteMessageAsync(messageId, userId);
            return deleted ? NoContent() : NotFound();
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error deleting message {MessageId}.", messageId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("messages/search")]
    public async Task<IActionResult> SearchMessages([FromBody] SearchMessagesRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.SearchMessagesAsync(request, userId);
            return Ok(result);
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error searching messages in community {CommunityId}.", request.CommunityId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("messages/{messageId:int}/report")]
    public async Task<IActionResult> ReportMessage(int messageId, [FromBody] ReportMessageRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            await _communityService.ReportMessageAsync(messageId, userId, request.Reason);
            return Ok(new { message = "Message reported." });
        }
        catch (NotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error reporting message {MessageId}.", messageId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("{communityId:int}/media")]
    [RequestSizeLimit(MaxImageSizeBytes)]
    public async Task<IActionResult> UploadMessageImage(int communityId, IFormFile? file)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "No file was uploaded." });
        }
        if (file.Length > MaxImageSizeBytes)
        {
            return BadRequest(new { message = "File exceeds the 10MB size limit." });
        }
        if (!AllowedImageContentTypes.Contains(file.ContentType))
        {
            return BadRequest(new { message = "Unsupported file type. Allowed: jpeg, png, webp." });
        }

        try
        {
            await using var stream = file.OpenReadStream();
            var url = await _communityService.UploadMessageImageAsync(communityId, userId, stream, file.FileName, file.ContentType);
            return Ok(new { url });
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error uploading a shared image for community {CommunityId}.", communityId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    // ---------------- Participants ----------------

    [HttpGet("{communityId:int}/participants")]
    public async Task<IActionResult> GetParticipants(int communityId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var result = await _communityService.GetParticipantsAsync(communityId, userId);
            return Ok(result);
        }
        catch (ForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching participants for community {CommunityId}.", communityId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }
}
