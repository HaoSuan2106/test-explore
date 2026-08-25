namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

/// <summary>
/// Raw place data pulled from the Google Places API (Nearby Search / Place Details),
/// already mapped into the shape the discovery algorithm needs. This class deliberately
/// knows nothing about HTTP or Google's JSON shape — that mapping belongs in the Places API
/// client, not here, so the algorithm below stays easy to unit test.
/// </summary>
public class PlaceCandidate
{
    /// <summary>Google Places "place_id" / "id" — stable key, used later to fetch details/photos.</summary>
    public required string PlaceId { get; init; }

    public required string Name { get; init; }

    /// <summary>e.g. "restaurant", "tourist_attraction", "cafe" — Places API primaryType/first type.</summary>
    public required string PrimaryType { get; init; }

    public double Latitude { get; init; }
    public double Longitude { get; init; }

    /// <summary>Average rating 0.0-5.0. Null when Google has no rating yet.</summary>
    public double? Rating { get; init; }

    /// <summary>Total number of user ratings/reviews. This is the main "popularity" proxy signal.</summary>
    public int UserRatingCount { get; init; }

    /// <summary>0 (free) - 4 (very expensive). Null when unknown. Not used in scoring yet, kept for future filters.</summary>
    public int? PriceLevel { get; init; }

    /// <summary>e.g. "OPERATIONAL", "CLOSED_TEMPORARILY", "CLOSED_PERMANENTLY".</summary>
    public string BusinessStatus { get; init; } = "OPERATIONAL";
}
