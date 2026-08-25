namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

/// <summary>Output of the discovery algorithm: a candidate place plus its computed "hidden gem" score.</summary>
public class HiddenPlaceResult
{
    public required PlaceCandidate Place { get; init; }

    /// <summary>0.0-1.0. Higher = more "hidden gem" (obscure but good). Sort descending to rank for display.</summary>
    public double HiddenScore { get; init; }

    /// <summary>0.0-1.0 popularity signal used in scoring (0 = obscure, 1 = very popular locally). Exposed for debugging/tuning.</summary>
    public double PopularityNorm { get; init; }

    /// <summary>0.0-1.0 normalized rating signal used in scoring. Exposed for debugging/tuning.</summary>
    public double RatingNorm { get; init; }
}
