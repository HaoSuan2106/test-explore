using ExploreMy.Api.DataAccess.ExternalClients.OpenRouteService;
using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.Navigation;

public class NavigationService : INavigationService
{
    private readonly IRoutingApiClient _routingApiClient;

    public NavigationService(IRoutingApiClient routingApiClient)
    {
        _routingApiClient = routingApiClient;
    }

    public async Task<RouteResponseDto> GetRouteAsync(RouteRequestDto request)
    {
        var result = await _routingApiClient.GetRouteAsync(
            request.OriginLatitude,
            request.OriginLongitude,
            request.DestinationLatitude,
            request.DestinationLongitude,
            request.Profile);

        return new RouteResponseDto
        {
            DistanceMeters = result.DistanceMeters,
            DurationSeconds = result.DurationSeconds,
            Points = result.Points
                .Select(p => new RoutePointDto { Latitude = p.Latitude, Longitude = p.Longitude })
                .ToList(),
        };
    }
}