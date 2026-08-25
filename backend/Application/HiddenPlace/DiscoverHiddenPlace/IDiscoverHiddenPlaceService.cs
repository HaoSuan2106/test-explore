namespace ExploreMy.Api.Application.HiddenPlace.DiscoverHiddenPlace;

public interface IDiscoverHiddenPlaceService
{
    /// <summary>
    /// Filters and scores raw Places API candidates, returning only places that pass the quality gate,
    /// ranked from most "hidden gem" to least "hidden gem".
    /// </summary>
    /// <param name="candidates">Places already fetched from Google Places API (Nearby Search / Place Details).</param>
    /// <param name="options">Thresholds/weights; pass null to use the defaults.</param>
    IReadOnlyList<HiddenPlaceResult> Discover(
        IEnumerable<PlaceCandidate> candidates,
        DiscoverHiddenPlaceOptions? options = null);

    /// <summary>
    /// Runs just the stage-1 quality gate against a single candidate (business status, rating, review
    /// count, chain-brand name check) - the part of the algorithm that doesn't depend on comparing
    /// against other nearby places. Used to tag raw cached rows with whether they'd pass, without
    /// running the full Discover pipeline. See DiscoverHiddenPlaceService.PassesQualityGate.
    /// </summary>
    bool PassesQualityGate(PlaceCandidate place, DiscoverHiddenPlaceOptions? options = null);
}
