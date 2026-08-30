using NetTopologySuite.Features;
using NetTopologySuite.Geometries;
using NetTopologySuite.IO.Converters;
using System.Text.Json;

public interface IDistrictLookupService
{
    string? FindDistrict(double latitude, double longitude);
}

public class DistrictLookupService : IDistrictLookupService
{
    private readonly List<(string DistrictName, Geometry Geometry)> _districts;

    public DistrictLookupService(IWebHostEnvironment env)
    {
        var path = Path.Combine(env.ContentRootPath, "Data", "malaysia.district.geojson");
        var json = File.ReadAllText(path);

        var options = new JsonSerializerOptions();
        options.Converters.Add(new GeoJsonConverterFactory());

        var featureCollection = JsonSerializer.Deserialize<FeatureCollection>(json, options)!;

        _districts = featureCollection.Select(f => (
            DistrictName: (string)f.Attributes["name"],
            Geometry: f.Geometry
        )).ToList();
    }

    public string? FindDistrict(double latitude, double longitude)
    {
        var point = new Point(longitude, latitude); // NTS order is (X=lng, Y=lat) — opposite of LatLng!
        foreach (var (name, geometry) in _districts)
        {
            if (geometry.Contains(point)) return name;
        }
        return null; // point fell outside every district — offshore, bad data, etc.
    }


}
