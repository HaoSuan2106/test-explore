namespace ExploreMy.Api.DataAccess.ExternalClients.OpenRouteService;

public class RoutePoint
{
    public double Latitude { get; set; }
    public double Longitude { get; set; }
}

public class RouteResult
{
    public List<RoutePoint> Points { get; set; } = new();
    public double DistanceMeters { get; set; }
    public double DurationSeconds { get; set; }
}

public interface IRoutingApiClient
{
    Task<RouteResult> GetRouteAsync(
        double originLat, double originLng,
        double destLat, double destLng,
        string profile = "foot-walking");
}