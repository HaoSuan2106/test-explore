namespace ExploreMy.Api.Application.HiddenPlace.Facade;

/// <summary>One unit of work: "fetch this place type within this circle", plus the cache bucket key it maps to.</summary>
public record SearchBucket(string BucketKey, string PlaceType, double CenterLatitude, double CenterLongitude, int RadiusMeters);

/// <summary>
/// Splits one "search near (lat,lng) within radius, for these types" request into a small, bounded
/// set of (type, geographic cell) buckets - combining two ideas at once:
///
///   - per-TYPE requests: Google Places' searchNearby has no pagination, so one call to it is capped
///     at 20 results total across whatever types you pass in. Querying restaurant/cafe/
///     tourist_attraction/etc. separately gives each type its own 20-result budget instead of all of
///     them fighting over one shared 20.
///   - per-CELL requests: splitting a big radius into smaller circles lets a dense area return more
///     than 20 total results instead of being capped at 20 for the whole radius.
///
/// Cells snap to a FIXED global grid (not centered on the caller's exact coordinates), so two nearby
/// users searching overlapping areas produce the SAME bucket keys and can share one cache entry -
/// see HiddenPlaceService, which checks the cache before deciding what actually needs to hit Google.
///
/// Cell SIZE is a fixed constant, independent of the caller's requested radius - it does NOT shrink or
/// grow based on radiusMeters. This matters: if cell size scaled with radiusMeters (as an earlier
/// version of this class did), a 10km search and a 2km search at the same location would compute
/// different cell sizes, land on different (row, col) numbering, and never share a cache bucket even
/// though they cover overlapping ground. With a fixed cell size, any two requests - whatever radius
/// they ask for - that touch the same real-world cell produce the exact same bucket key. What varies
/// per request instead is how many cells OUT from the center get scanned (see BuildBuckets).
///
/// Two separate lengths are at play and must not be conflated (they were, once - see
/// CellSearchRadiusMeters for what that cost): CellHalfWidthMeters defines the SQUARE grid the bucket
/// keys come from, while CellSearchRadiusMeters is the radius of the CIRCLE each Google call actually
/// covers. Google only searches circles, the grid only tiles squares, and a circle has to be the
/// square's circumscribed one - not its inscribed one - for the squares' corners to be covered at all.
/// </summary>
public static class SearchGridPlanner
{
    /// <summary>Half the width of one grid cell, i.e. the grid's spacing is twice this. Fixed for every
    /// request regardless of radiusMeters, since this is what the (row, col) bucket keys are derived from
    /// - changing it invalidates every cached bucket. Bigger cells mean fewer buckets (fewer Google calls
    /// / cache rows) per search, at the cost of each bucket covering more ground - each cell is still only
    /// ever backed by one Google call per type, so a bucket that's "too big" for a dense area will lose
    /// results past Google's 20-per-call cap (a dense cell can easily have 50+ restaurants in it, but a
    /// "restaurant" call for that cell only ever gets 20 of them back - the rest are silently dropped).
    /// Sized against RadiusMeters' allowed values (2.5km or 5km - see DiscoverHiddenPlaceRequestDto): a
    /// 4km-wide cell needs 1 ring of neighbors to cover a 2.5km search and 2 rings for 5km (see
    /// MaxCellStepsFromCenter), which keeps the worst case (5km, first-time/no cache) to roughly ~20
    /// buckets per place type.</summary>
    private const int CellHalfWidthMeters = 2000;

    /// <summary>The radius each cell's Google Places call actually uses. This is the cell square's
    /// CIRCUMSCRIBED circle (half-diagonal = half-width x sqrt 2), NOT its inscribed circle - and that
    /// distinction is load-bearing, not a detail.
    ///
    /// This used to be the same constant as CellHalfWidthMeters, which made every search circle the
    /// inscribed circle of its cell. Circles of radius r centered on a grid of spacing 2r are mutually
    /// TANGENT: they meet at the edge midpoints but never reach the corners, so the curved-diamond gaps
    /// around every grid corner were searched by no call at all. That leaves 1 - pi/4 = 21.5% of the map
    /// permanently invisible to the app, which measured out as ~22% of places inside the user's radius
    /// simply never being fetched, at every radius. Circumscribing instead guarantees every square metre
    /// of every scanned cell is inside at least one call's circle.
    ///
    /// The cost is deliberate overlap: neighboring circles now intersect, so the same place comes back
    /// from more than one bucket. That is already handled - HiddenPlaceService dedupes by PlaceId.</summary>
    private static readonly int CellSearchRadiusMeters =
        (int)Math.Ceiling(CellHalfWidthMeters * Math.Sqrt(2));

    /// <summary>Hard cap on how many cells out from the center we'll scan per axis. With RadiusMeters
    /// locked to 2.5km or 5km and a 4km-wide cell, those need 1 and 2 rings respectively, so the cap does
    /// not bind at all today - BuildBuckets already computes the smaller number it needs.
    ///
    /// Left at 3 rather than lowered to 2 because it is a ceiling, not a target: costing nothing while it
    /// is unreached, and covering a 10km option if one is ever offered again (rings work out to 1 / 2 / 2
    /// / 3 for 2.5 / 5 / 7.5 / 10km - verified by simulation at 240k sampled places per radius, zero
    /// missed). Only raise it if a radius larger than 10km is added.</summary>
    private const int MaxCellStepsFromCenter = 3;

    private const double MetersPerDegreeLatitude = 111_320;

    /// <summary>
    /// Returns one SearchBucket per (placeType x grid cell overlapping the search circle).
    /// </summary>
    public static List<SearchBucket> BuildBuckets(
        double centerLatitude, double centerLongitude, int radiusMeters, IReadOnlyList<string> placeTypes)
    {
        var cellSizeDegreesLat = CellHalfWidthMeters * 2 / MetersPerDegreeLatitude;
        var metersPerDegreeLng = MetersPerDegreeLatitude * Math.Cos(DegreesToRadians(centerLatitude));
        var cellSizeDegreesLng = CellHalfWidthMeters * 2 / Math.Max(metersPerDegreeLng, 1);

        // How far out (in cells) we need to scan to fully cover the requested radius, capped so a large
        // radiusMeters can't blow up the bucket count - see MaxCellStepsFromCenter's doc comment.
        var stepsNeeded = (int)Math.Ceiling((double)radiusMeters / (CellHalfWidthMeters * 2));
        var steps = Math.Clamp(stepsNeeded, 1, MaxCellStepsFromCenter);

        var seenCells = new HashSet<(int Row, int Col)>();
        var cells = new List<(int Row, int Col, double Lat, double Lng)>();

        for (var rowOffset = -steps; rowOffset <= steps; rowOffset++)
        {
            for (var colOffset = -steps; colOffset <= steps; colOffset++)
            {
                var probeLat = centerLatitude + rowOffset * cellSizeDegreesLat;
                var probeLng = centerLongitude + colOffset * cellSizeDegreesLng;

                // Snap to the FIXED global grid, so the same real-world cell always maps to the same
                // (row, col) no matter which user's request generated it, and no matter what radius they
                // asked for - that's what lets separate requests share one cache bucket.
                var row = (int)Math.Floor(probeLat / cellSizeDegreesLat);
                var col = (int)Math.Floor(probeLng / cellSizeDegreesLng);

                if (!seenCells.Add((row, col)))
                {
                    continue;
                }

                var snappedLat = (row + 0.5) * cellSizeDegreesLat;
                var snappedLng = (col + 0.5) * cellSizeDegreesLng;

                // Measure against the SNAPPED cell center, never the probe point above. The probe is only
                // a "which cell is roughly over here" marker built by stepping whole cell widths from the
                // caller's exact position; because the grid is global and the caller sits at an arbitrary
                // spot inside their own cell, the probe can land up to a half-diagonal (~2.8km) away from
                // the center of the cell it falls in. Measuring the probe instead - as this used to -
                // meant the test was answering a question about a point no call is ever centered on, so
                // it both admitted cells that cannot reach the user and rejected cells that can.
                //
                // With the snapped center, this is the exact "do these two circles intersect at all?"
                // test: skip the cell only when its search circle cannot touch the requested one.
                if (DistanceMeters(centerLatitude, centerLongitude, snappedLat, snappedLng)
                    > radiusMeters + CellSearchRadiusMeters)
                {
                    continue;
                }

                cells.Add((row, col, snappedLat, snappedLng));
            }
        }

        var buckets = new List<SearchBucket>();
        foreach (var cell in cells)
        {
            foreach (var placeType in placeTypes)
            {
                var bucketKey = $"{placeType}:{cell.Row}:{cell.Col}";
                buckets.Add(new SearchBucket(bucketKey, placeType, cell.Lat, cell.Lng, CellSearchRadiusMeters));
            }
        }
        return buckets;
    }

    internal static double DegreesToRadians(double degrees) => degrees * Math.PI / 180;

    /// <summary>Exposed as internal (not private) so HiddenPlaceService can apply an exact per-place
    /// distance filter after fetching a cell's results - cell membership above is deliberately loose
    /// (a whole cell is included if it merely overlaps the search radius), so individual places inside
    /// an included cell can be farther from the user than the radius they asked for. This method is the
    /// one source of truth for "how far is X from Y", reused for that exact-distance check.</summary>
    internal static double DistanceMeters(double lat1, double lng1, double lat2, double lng2)
    {
        // Equirectangular approximation - plenty accurate at a few-km scale, and much cheaper than
        // full haversine for something evaluated dozens of times per request.
        var metersPerDegreeLng = MetersPerDegreeLatitude * Math.Cos(DegreesToRadians((lat1 + lat2) / 2));
        var dLat = (lat2 - lat1) * MetersPerDegreeLatitude;
        var dLng = (lng2 - lng1) * metersPerDegreeLng;
        return Math.Sqrt(dLat * dLat + dLng * dLng);
    }
}
