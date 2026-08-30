using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using ExploreMy.Api.Configuration;

namespace ExploreMy.Api.DataAccess.ExternalClients.OpenRouteService;

public class OpenRouteServiceApiClient : IRoutingApiClient
{
    private readonly HttpClient _httpClient;
    private readonly OpenRouteServiceSettings _settings;

    public OpenRouteServiceApiClient(HttpClient httpClient, IOptions<OpenRouteServiceSettings> options)
    {
        _httpClient = httpClient;
        _settings = options.Value;
    }

    public async Task<RouteResult> GetRouteAsync(
        double originLat, double originLng,
        double destLat, double destLng,
        string profile = "foot-walking")
    {
        // ORS expects coordinates as [longitude, latitude], the opposite of
        // the (lat, lng) convention used everywhere else in this project.
        var requestBody = new
        {
            coordinates = new[]
            {
                new[] { originLng, originLat },
                new[] { destLng, destLat },
            },
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, $"/v2/directions/{profile}/geojson")
        {
            Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json"),
        };
        // ORS expects the raw key with no "Bearer " prefix.
        request.Headers.TryAddWithoutValidation("Authorization", _settings.ApiKey);

        var response = await _httpClient.SendAsync(request);
        var json = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"OpenRouteService request failed ({(int)response.StatusCode} {response.StatusCode}): {json}");
        }
        using var doc = JsonDocument.Parse(json);

        var feature = doc.RootElement.GetProperty("features")[0];
        var summary = feature.GetProperty("properties").GetProperty("summary");
        var coordinates = feature.GetProperty("geometry").GetProperty("coordinates");

        var result = new RouteResult
        {
            DistanceMeters = summary.GetProperty("distance").GetDouble(),
            DurationSeconds = summary.GetProperty("duration").GetDouble(),
        };

        foreach (var coord in coordinates.EnumerateArray())
        {
            result.Points.Add(new RoutePoint
            {
                Longitude = coord[0].GetDouble(),
                Latitude = coord[1].GetDouble(),
            });
        }

        return result;
    }
}