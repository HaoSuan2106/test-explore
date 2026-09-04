using ExploreMy.Api.Application.HiddenPlace.Facade;
using ExploreMy.Api.Common.Helpers;

namespace ExploreMy.Api.Tests;

/// <summary>
/// UNIT tests for the static SearchGridPlanner helper (public API surface only —
/// DistanceMeters is internal, so distance math is verified via the public GeoDistance helper).
/// </summary>
public class SearchGridPlannerTests
{
    [Fact]
    public void BuildBuckets_Returns_Buckets_For_Each_Type()
    {
        var buckets = SearchGridPlanner.BuildBuckets(3.14, 101.69, 5000, ["restaurant", "cafe"]);

        Assert.NotEmpty(buckets);
        // Each bucket has a unique key
        Assert.Equal(buckets.Count, buckets.Select(b => b.BucketKey).Distinct().Count());
        // All types present
        var types = buckets.Select(b => b.PlaceType).Distinct().OrderBy(t => t).ToList();
        Assert.Contains("restaurant", types);
        Assert.Contains("cafe", types);
    }

    [Fact]
    public void BuildBuckets_With_No_Types_Returns_Empty()
    {
        var buckets = SearchGridPlanner.BuildBuckets(3.14, 101.69, 5000, []);
        Assert.Empty(buckets);
    }

    [Fact]
    public void BuildBuckets_Returns_More_Buckets_For_Larger_Radius()
    {
        var small = SearchGridPlanner.BuildBuckets(3.14, 101.69, 1000, ["restaurant"]);
        var large = SearchGridPlanner.BuildBuckets(3.14, 101.69, 5000, ["restaurant"]);

        Assert.True(large.Count >= small.Count,
            "Larger radius should produce at least as many buckets as a smaller radius.");
    }

    [Fact]
    public void BuildBuckets_Bucket_Key_Is_TypePrefixed()
    {
        var buckets = SearchGridPlanner.BuildBuckets(3.14, 101.69, 5000, ["restaurant"]);
        Assert.NotEmpty(buckets);
        foreach (var b in buckets)
        {
            Assert.StartsWith("restaurant:", b.BucketKey);
        }
    }

    [Fact]
    public void BuildBuckets_Records_Positive_Radius()
    {
        var buckets = SearchGridPlanner.BuildBuckets(3.14, 101.69, 5000, ["restaurant"]);
        Assert.NotEmpty(buckets);
        Assert.True(buckets[0].RadiusMeters > 0);
    }

    // Distance math is delegated to the public GeoDistance helper.
    [Fact]
    public void GeoDistance_Returns_Zero_For_Same_Point()
    {
        var d = GeoDistance.EquirectangularMeters(3.14, 101.69, 3.14, 101.69);
        Assert.Equal(0, d, 0.001);
    }

    [Fact]
    public void GeoDistance_Returns_Positive_For_Different_Points()
    {
        // KL to PJ ~10-15km
        var d = GeoDistance.EquirectangularMeters(3.157, 101.712, 3.073, 101.606);
        Assert.True(d > 10_000);
        Assert.True(d < 20_000);
    }

    [Fact]
    public void GeoDistance_Is_Symmetric()
    {
        var d1 = GeoDistance.EquirectangularMeters(3.14, 101.69, 3.20, 101.75);
        var d2 = GeoDistance.EquirectangularMeters(3.20, 101.75, 3.14, 101.69);
        Assert.Equal(d1, d2, 0.001);
    }

    [Fact]
    public void GeoDistance_Haversine_Matches_Equirectangular_Within_Tolerance()
    {
        // The two formulas can disagree by ~0.3% at mid-latitudes for nearby points.
        var lat1 = 3.14; var lng1 = 101.69;
        var lat2 = 3.16; var lng2 = 101.72;
        var hav = GeoDistance.HaversineMeters(lat1, lng1, lat2, lng2);
        var eqr = GeoDistance.EquirectangularMeters(lat1, lng1, lat2, lng2);
        Assert.InRange(hav, eqr * 0.9, eqr * 1.1);
    }
}