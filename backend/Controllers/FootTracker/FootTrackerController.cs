using System.Security.Claims;
using ExploreMy.Api.Application.FootTracker.Facade;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.DTOs.FootTracker;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ExploreMy.Api.Controllers.FootTracker;

[Route("api/foot-tracker")]
[ApiController]
[Authorize]
public class FootTrackerController : ControllerBase
{
    private readonly IFootTrackerService _footTrackerService;
    private readonly ILogger<FootTrackerController> _logger;

    public FootTrackerController(IFootTrackerService footTrackerService, ILogger<FootTrackerController> logger)
    {
        _footTrackerService = footTrackerService;
        _logger = logger;
    }

    [HttpGet("favourite-places")]
    public async Task<IActionResult> GetFavouritePlaces()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            var places = await _footTrackerService.GetFavouritePlacesAsync(userId);
            return Ok(places);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching favourite places for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("favourite-places")]
    public async Task<IActionResult> AddFavouritePlace([FromBody] AddFavouritePlaceRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            var place = await _footTrackerService.AddFavouritePlaceAsync(userId, request);
            return StatusCode(StatusCodes.Status201Created, place);
        }
        catch (ConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error adding favourite place for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpDelete("favourite-places")]
    public async Task<IActionResult> RemoveFavouritePlaces([FromBody] RemoveFavouritePlacesRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        try
        {
            await _footTrackerService.RemoveFavouritePlacesAsync(userId, request);
            return Ok(new { message = "Place has been removed from your favourite list successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error removing favourite places for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }

    [HttpPost("route")]
    public async Task<IActionResult> GetRoute([FromBody] RouteRequestDto request)
    {
        try
        {
            var route = await _footTrackerService.GetRouteAsync(request);
            return Ok(route);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to compute route");
            return StatusCode(500, new { message = "Failed to compute route." });
        }
    }

    [HttpPost("visits")]
    public async Task<IActionResult> RecordVisit([FromBody] RecordVisitRequestDto request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var visit = await _footTrackerService.RecordVisitAsync(userId, request);
            return StatusCode(StatusCodes.Status201Created, visit);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error recording visit for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }

    [HttpGet("visits")]
    public async Task<IActionResult> GetVisits()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var visits = await _footTrackerService.GetVisitsAsync(userId);
            return Ok(visits);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching visits for user {UserId}.", userId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An unexpected error occurred." });
        }
    }
}