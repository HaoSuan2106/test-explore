using ExploreMy.Api.Application.HiddenPlace.Facade;
using ExploreMy.Api.DTOs.HiddenPlace;
using Microsoft.AspNetCore.Mvc;

namespace ExploreMy.Api.Controllers.HiddenPlace;

[ApiController]
[Route("api/hidden-places")]
public class HiddenPlaceController : ControllerBase
{
    private readonly IHiddenPlaceService _hiddenPlaceService;
    private readonly ILogger<HiddenPlaceController> _logger;

    public HiddenPlaceController(IHiddenPlaceService hiddenPlaceService, ILogger<HiddenPlaceController> logger)
    {
        _hiddenPlaceService = hiddenPlaceService;
        _logger = logger;
    }

    /// <summary>
    /// Discovers hidden-gem places (attractions/restaurants/etc.) near a point, ranked from most to
    /// least "hidden". Backed by Google Places API plus the app's own popularity-scoring algorithm.
    /// Example: GET /api/hidden-places/discover?latitude=3.139&longitude=101.6869&radiusMeters=3000
    /// </summary>
    [HttpGet("discover")]
    public async Task<ActionResult<List<HiddenPlaceResponseItemDto>>> Discover(
        [FromQuery] DiscoverHiddenPlaceRequestDto request,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await _hiddenPlaceService.DiscoverHiddenPlacesAsync(request, cancellationToken);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            // Thrown by GooglePlacesApiClient when the upstream Places API call fails.
            _logger.LogError(ex,
                "Places API call failed while discovering hidden places near ({Lat}, {Lng}).",
                request.Latitude, request.Longitude);
            return StatusCode(StatusCodes.Status502BadGateway,
                new { message = "Failed to reach Google Places API." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Unexpected error discovering hidden places near ({Lat}, {Lng}).",
                request.Latitude, request.Longitude);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "An unexpected error occurred." });
        }
    }
}
