namespace ExploreMy.Api.DataAccess.Repositories.HiddenPlace;

/// <summary>
/// Kept separate from IHiddenPlaceRepository rather than added to it. That interface is shared with
/// the recommended-places module and is edited by more than one person; a suppression list is a
/// small, self-contained concern, and giving it its own file keeps the two out of each other's way.
/// </summary>
public interface IHiddenPlaceSuppressionRepository
{
    /// <summary>
    /// Every suppressed Google place id, as a set ready for membership checks.
    ///
    /// Loaded whole rather than queried per search because the list is small by nature - it only
    /// grows when five separate people report the same place - and one small read beats sending a
    /// few hundred candidate ids to the database on every search. Revisit if it ever reaches the
    /// thousands.
    /// </summary>
    Task<HashSet<string>> GetSuppressedPlaceIdsAsync();

    /// <summary>
    /// Records that a place must no longer be shown. Safe to call more than once for the same place:
    /// a repeat is ignored rather than treated as an error, so a report flow does not need to check
    /// first.
    /// </summary>
    Task SuppressAsync(string placeId, string? name, string? reason, int reportCount);
}
