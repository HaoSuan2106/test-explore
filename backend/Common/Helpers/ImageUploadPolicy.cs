namespace ExploreMy.Api.Common.Helpers;

/// <summary>
/// The single upload-validation policy for image uploads across the app (V-12).
///
/// The 5 MB size cap is one constant. The allowed content-type sets are deliberately
/// per-feature because the product allows different formats for different kinds of
/// images: community posts are JPEG/PNG only, while recommended-place photos and
/// review photos additionally accept WebP. Keep these sets in step with the
/// frontend pickers — changing an allowed format here is the one place that needs
/// editing.
/// </summary>
public static class ImageUploadPolicy
{
    public const long MaxSizeBytes = 5 * 1024 * 1024;

    /// <summary>Community post images: JPEG/PNG only.</summary>
    public static readonly HashSet<string> PostImageContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
    };

    /// <summary>Recommended-place photos: JPEG/PNG/WebP.</summary>
    public static readonly HashSet<string> RecommendedPlaceImageContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
        "image/webp",
    };

    /// <summary>Review photos: JPEG/PNG/WebP.</summary>
    public static readonly HashSet<string> ReviewImageContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
        "image/webp",
    };

    public static bool IsAllowedImageType(string? contentType, IReadOnlySet<string> allowedContentTypes)
        => !string.IsNullOrWhiteSpace(contentType) && allowedContentTypes.Contains(contentType);
}
