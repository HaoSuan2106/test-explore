namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// A Google-sourced place the community has voted out - closed down, wrong location, inappropriate -
/// which must stop appearing in search results.
///
/// This table exists because you cannot hide a cached place by deleting it. hidden_place_cache is
/// refilled from Google on a 30-day cycle: delete the row and the place is simply fetched again the
/// next time someone searches that area, and every report against it is quietly undone. The place
/// has to be excluded at read time instead, by something Google's refresh cannot touch - which is
/// what this is.
///
/// Note the asymmetry with community submissions. A recommended_places row is OUR data, so hiding it
/// is just a status change on the row itself. A Google place is not ours to edit, so all we can keep
/// is a note saying "never show this one".
/// </summary>
public class HiddenPlaceSuppression
{
    public int HiddenPlaceSuppressionId { get; set; }

    /// <summary>Google's place id. The same key hidden_place_cache.place_id uses.</summary>
    public string PlaceId { get; set; } = string.Empty;

    /// <summary>Name at the time it was suppressed, so the row is readable by a human later.</summary>
    public string? Name { get; set; }

    /// <summary>Why - taken from the reports that triggered it.</summary>
    public string? Reason { get; set; }

    /// <summary>How many unique reports pushed it over the threshold. Kept as evidence.</summary>
    public int ReportCount { get; set; }

    public DateTime SuppressedAt { get; set; }
}
