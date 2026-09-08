namespace ExploreMy.Api.Domain.Entities;

public class MessageAttachment
{
    public int AttachmentId { get; set; }
    public int MessageId { get; set; }
    public string Type { get; set; } = string.Empty; // "Image" | "PlaceShare" | "PostShare"

    public string? MediaUrl { get; set; }

    // Real place identifiers are strings (a Google Place ID, or a recommended
    // place's submission UUID) — never an int. See Share Location.
    public string? PlaceId { get; set; }
    public string? PlaceName { get; set; }
    public string? PlaceAddress { get; set; }
    public string? PlaceImageUrl { get; set; }
    public string? PlaceStatus { get; set; }

    /// <summary>
    /// Coordinates + category snapshot taken at share time, so reopening the
    /// shared place (Share Location's "tap to view") never needs a live
    /// re-fetch from another module's backend — it reconstructs a lightweight
    /// PlaceData the same way FavouritePlaceScreen/ExplorationHistory already
    /// do for their own lists (rating/hours/photos omitted, just the fields
    /// needed to open PlaceDetailUI and use its actions).
    /// </summary>
    public double? PlaceLatitude { get; set; }
    public double? PlaceLongitude { get; set; }
    public string? PlacePrimaryType { get; set; }

    /// <summary>True when PlaceId is a recommend_place_id (community submission) rather than a Google Place ID.</summary>
    public bool IsCommunityPlace { get; set; }

    // Post share snapshot (Type == "PostShare") — same lightweight-snapshot
    // approach as PlaceShare above, but PostDetailsScreen self-fetches by id
    // on open, so only enough is stored here to render a preview bubble in
    // chat; the tap target just navigates to /post/details/{PostId}.
    public string? PostId { get; set; }
    public string? PostTitle { get; set; }
    public string? PostImageUrl { get; set; }
    public string? PostAuthorName { get; set; }
    public string? PostLocation { get; set; }
}
