using ExploreMy.Api.DTOs.FootTracker;

namespace ExploreMy.Api.Application.FootTracker.Navigation;

public interface INavigationService
{
    Task<RouteResponseDto> GetRouteAsync(RouteRequestDto request);
}