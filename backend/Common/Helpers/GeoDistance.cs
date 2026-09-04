namespace ExploreMy.Api.Common.Helpers;

/// <summary>
/// Single source of truth for geographic distance computations (V-07 / V-10).
///
/// Two formulas live here side by side because the app genuinely uses two, each chosen
/// for the job it does:
///
///  - <see cref="HaversineMeters"/>: the great-circle distance on a sphere. Used where a
///    few metres of precision matter — the recommended-place duplicate check (a 100 m
///    proximity radius). More expensive (trigonometry per pair), but the input set is small.
///
///  - <see cref="EquirectangularMeters"/>: the equirectangular (flat-earth) approximation,
///    much cheaper than haversine. Used by the discovery grid filter where it is evaluated
///    dozens of times per request at a few-kilometre scale, where it is plenty accurate.
///
/// The two can disagree by a small amount (order 0.3% at mid-latitudes). That divergence is
/// deliberate — each call site keeps its current formula so behaviour never changes; only the
/// code ownership is centralized here.
/// </summary>
public static class GeoDistance
{
    /// <summary>Mean Earth radius in metres (WGS-84 mean radius).</summary>
    public const double EarthRadiusMeters = 6371000.0;

    /// <summary>Approximate length of one degree of latitude in metres.</summary>
    public const double MetersPerDegreeLatitude = 111_320;

    public static double DegreesToRadians(double degrees) => degrees * Math.PI / 180;

    /// <summary>
    /// Great-circle distance between two points in metres, using the haversine formula.
    /// </summary>
    public static double HaversineMeters(double lat1, double lon1, double lat2, double lon2)
    {
        double ToRad(double deg) => deg * Math.PI / 180.0;

        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
                + Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2))
                * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return EarthRadiusMeters * c;
    }

    /// <summary>
    /// Distance between two points in metres using the equirectangular (flat-earth)
    /// approximation — accurate at a few-kilometre scale, much cheaper than haversine.
    /// </summary>
    public static double EquirectangularMeters(double lat1, double lng1, double lat2, double lng2)
    {
        var metersPerDegreeLng = MetersPerDegreeLatitude * Math.Cos(DegreesToRadians((lat1 + lat2) / 2));
        var dLat = (lat2 - lat1) * MetersPerDegreeLatitude;
        var dLng = (lng2 - lng1) * metersPerDegreeLng;
        return Math.Sqrt(dLat * dLat + dLng * dLng);
    }
}
