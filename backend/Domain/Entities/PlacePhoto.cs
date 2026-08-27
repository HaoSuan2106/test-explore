namespace ExploreMy.Api.Domain.Entities;

/// <summary>
/// One place's cover photo, already copied out of Google and into our own Supabase bucket.
///
/// This table exists for one reason: money. Google's Place Photos endpoint bills per image fetched
/// ($7 per 1,000, 1,000 free a month), and a photo URI it hands back expires, so an app that wants
/// to show a picture has to pay again every time. Copying the bytes once and keeping our own URL
/// means a given place is paid for exactly once, ever.
///
/// It is deliberately NOT part of hidden_place_cache. That table is disposable by design - a bucket
/// is deleted and re-fetched wholesale when it goes stale, and the whole table is safe to TRUNCATE.
/// A photo URL living there would be destroyed on every cache refresh and re-bought from Google, so
/// the cache's cheapness would quietly become an expense. Rows here are keyed by place id alone,
/// have no expiry, and survive anything done to the cache.
///
/// One row per place: only the first photo Google offers is copied, which is the one the app shows
/// on the card and in the details view.
/// </summary>
public class PlacePhoto
{
    public int PlacePhotoId { get; set; }

    /// <summary>Google's stable place id - the join key back to hidden_place_cache.place_id.</summary>
    public string PlaceId { get; set; } = string.Empty;

    /// <summary>Public URL of our own copy in Supabase Storage. This is what the app loads.</summary>
    public string PhotoUrl { get; set; } = string.Empty;

    /// <summary>
    /// The Google photo resource name the copy was made from, e.g.
    /// "places/ChIJ.../photos/AeJbb3E...". Kept for traceability: if an image ever needs to be
    /// re-fetched at a different size, this is the handle to do it with, without another search call.
    /// </summary>
    public string? PhotoReference { get; set; }

    /// <summary>
    /// The photographer credit Google returned with the photo (authorAttributions[0].displayName).
    ///
    /// Not decoration - Google's terms require the attribution to be displayed wherever the image is,
    /// and since we are serving the image from our own bucket, Google is no longer in a position to
    /// attach it for us. Null only when Google supplied none.
    /// </summary>
    public string? Attribution { get; set; }

    public DateTime CreatedAt { get; set; }
}
