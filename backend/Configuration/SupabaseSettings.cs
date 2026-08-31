namespace ExploreMy.Api.Configuration;

public class SupabaseSettings
{
    public string Url { get; set; } = string.Empty;
    /// <summary>Default bucket - profile pictures. Used whenever a caller does not name one.</summary>
    public string Bucket { get; set; } = string.Empty;

    /// <summary>
    /// Bucket holding place photos copied out of Google. Separate from the profile-picture bucket on
    /// purpose: these are third-party images under Google's terms rather than user uploads, there are
    /// far more of them, and keeping them apart means the whole lot can be emptied - or its retention
    /// policy changed - without touching anything a user owns.
    /// </summary>
    public string PlacePhotoBucket { get; set; } = string.Empty;
    public string ServiceRoleKey { get; set; } = string.Empty;
}
