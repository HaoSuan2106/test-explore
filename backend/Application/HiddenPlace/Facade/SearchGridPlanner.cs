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
/// </summary>
public static class SearchGridPlanner
{
    /// <summary>The one and only cell radius used for every request, regardless of radiusMeters. Bigger
    /// cells mean fewer buckets (fewer Google calls / cache rows) per search, at the cost of each bucket
    /// covering more ground - each cell is still only ever backed by one Google call per type, so a
    /// bucket that's "too big" for a dense area will lose results past Google's 20-per-call cap (a dense
    /// 6km-diameter cell can easily have 50+ restaurants in it, but a "restaurant" call for that cell
    /// only ever gets 20 of them back - the rest are silently dropped, which is what made results feel
    /// sparse). Sized against RadiusMeters' only two allowed values (5km / 10km - see
    /// DiscoverHiddenPlaceRequestDto): a 4km-diameter cell needs 2 rings of neighbors to fully cover a
    /// 5km search and 3 rings for a 10km search (see MaxCellStepsFromCenter), which keeps the worst case
    /// (10km, first-time/no cache) to roughly ~30 buckets per place type instead of a dozen - more Google
    /// calls than the old 3km cell radius, but each call now covers less ground so fewer real places get
    /// squeezed out by the 20-per-call cap.</summary>
    private const int FixedCellRadiusMeters = 2000;

    /// <summary>Hard cap on how many cells out from the center we'll scan per axis. With RadiusMeters
    /// locked to 5km or 10km and a 2km cell radius (4km diameter), 3 steps is exactly enough to fully
    /// cover the largest allowed request (10km) - see FixedCellRadiusMeters' doc comment. Bumping this
    /// higher only matters if a larger RadiusMeters option gets added later.</summary>
    private const int MaxCellStepsFromCenter = 3;

    private const double MetersPerDegreeLatitude = 111_320;

    /// <summary>
    /// Returns one SearchBucket per (placeType x grid cell overlapping the search circle).
    /// </summary>
    public static List<SearchBucket> BuildBuckets(
        double centerLatitude, double centerLongitude, int radiusMeters, IReadOnlyList<string> placeTypes)
    {
        const int cellRadiusMeters = FixedCellRadiusMeters;
        var cellSizeDegreesLat = cellRadiusMeters * 2 / MetersPerDegreeLatitude;
        var metersPerDegreeLng = MetersPerDegreeLatitude * Math.Cos(DegreesToRadians(centerLatitude));
        var cellSizeDegreesLng = cellRadiusMeters * 2 / Math.Max(metersPerDegreeLng, 1);

        // How far out (in cells) we need to scan to fully cover the requested radius, capped so a large
        // radiusMeters can't blow up the bucket count - see MaxCellStepsFromCenter's doc comment.
        var stepsNeeded = (int)Math.Ceiling((double)radiusMeters / (cellRadiusMeters * 2));
        var steps = Math.Clamp(stepsNeeded, 1, MaxCellStepsFromCenter);

        var seenCells = new HashSet<(int Row, int Col)>();
        var cells = new List<(int Row, int Col, double Lat, double Lng)>();

        for (var rowOffset = -steps; rowOffset <= steps; rowOffset++)
        {
            for (var colOffset = -steps; colOffset <= steps; colOffset++)
            {
                var approxLat = centerLatitude + rowOffset * cellSizeDegreesLat;
                var approxLng = centerLongitude + colOffset * cellSizeDegreesLng;

                if (DistanceMeters(centerLatitude, centerLongitude, approxLat, approxLng) > radiusMeters + cellRadiusMeters)
                {
                    continue; // this cell doesn't overlap the requested circle at all - skip it
                }

                // Snap to the FIXED global grid, so the same real-world cell always maps to the same
                // (row, col) no matter which user's request generated it, and no matter what radius they
                // asked for - that's what lets separate requests share one cache bucket.
                var row = (int)Math.Floor(approxLat / cellSizeDegreesLat);
                var col = (int)Math.Floor(approxLng / cellSizeDegreesLng);

                if (seenCells.Add((row, col)))
                {
                    var snappedLat = (row + 0.5) * cellSizeDegreesLat;
                    var snappedLng = (col + 0.5) * cellSizeDegreesLng;
                    cells.Add((row, col, snappedLat, snappedLng));
                }
            }
        }

        var buckets = new List<SearchBucket>();
        foreach (var cell in cells)
        {
            foreach (var placeType in placeTypes)
            {
                var bucketKey = $"{placeType}:{cell.Row}:{cell.Col}";
                buckets.Add(new SearchBucket(bucketKey, placeType, cell.Lat, cell.Lng, cellRadiusMeters));
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
