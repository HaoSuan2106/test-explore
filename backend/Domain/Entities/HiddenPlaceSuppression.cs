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

    /// <summary>
    /// The user who submitted this report. 0 = legacy / system-suppression rows
    /// (anonymous aggregate reports created before the user_id column was added).
    /// Real user reports always carry a positive user id.
    ///
    /// UNIQUE(user_id, place_id) enforces ONE ACTIVE REPORT per user+place,
    /// making second attempts by the same user a database-level rejection.
    /// </summary>
    public int UserId { get; set; }

    public string PlaceId { get; set; } = string.Empty;

    /// <summary>
    /// When the suppression originates from a recommended place (created via
    /// Recommend New Place), this holds the <c>recommend_place.place_id</c>
    /// value. <c>null</c> for suppression records that come from ordinary
    /// hidden places (Google Places data).
    /// </summary>
    public string? RecommendedPlaceId { get; set; }

    public string Name { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
    public int ReportCount { get; set; }
    public DateTime SuppressedAt { get; set; }
}
