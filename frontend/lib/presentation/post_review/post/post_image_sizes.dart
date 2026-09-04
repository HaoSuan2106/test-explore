/// Centralized network-image decode sizes for the Post / Community module.
///
/// Used as `memCacheWidth`/`memCacheHeight` on [CachedNetworkImage] so the
/// main isolate only ever decodes downscaled bitmaps:
///   * Post Feed → small thumbnail decode (cards never pull full resolution).
///   * Post Details → higher-resolution decode (large hero / gallery).
///   * Create/Edit → tiny preview thumbnails.
///
/// These are decode-budget hints (pixels the engine must produce), not
/// display sizes — they should stay close to the on-screen widget size
/// (× devicePixelRatio, typically ~2-3) and never be full source resolution.
///
/// This class also provides [thumbnailUrl] which transforms known CDN image
/// URLs to request a resized thumbnail instead of the full-size original.
/// The feed card only needs ~600px width, but the stored URLs reference
/// full-resolution originals (568 KB–1.4 MB). Appending resize parameters
/// reduces the download to ~16–42 KB per image (97 % reduction) without
/// changing the API contract or database schema. Hosts not in the supported
/// list are returned unchanged.
class PostImageSizes {
  PostImageSizes._();

  /// Author avatar decode size (feed card + details).
  static const int avatar = 120;

  /// Post Feed card gallery thumbnail decode size (16:10-ish crop).
  /// Reduced from 800×500 to 600×375 (44% fewer decoded pixels) to lower the
  /// per-image memory footprint during sustained feed browsing. Still ~1.8×
  /// the physical on-screen size at 3× DPR, so visual quality is preserved.
  static const int feedThumbnailWidth = 600;
  static const int feedThumbnailHeight = 375;

  /// Post Details hero / single image decode size.
  static const int detailsWidth = 1290;
  static const int detailsHeight = 806;

  /// Post Details horizontal gallery item decode size.
  static const int detailsGalleryWidth = 1020;
  static const int detailsGalleryHeight = 660;

  /// Create/Edit photo preview thumbnails (80px widgets).
  static const int editThumbnail = 240;

  /// Thumbnail width to request from CDNs that support server-side resize.
  /// Used by [thumbnailUrl] to append transform parameters.
  static const int _thumbWidth = 600;
  static const int _thumbHeight = 375;

  /// Transforms a known CDN image URL to request a server-side resized
  /// thumbnail, reducing the downloaded payload from full-resolution
  /// (568 KB–1.4 MB) to ~16–42 KB. Unsupported hosts are returned as-is.
  ///
  /// Supported CDNs:
  ///   * **Unsplash** (`images.unsplash.com`) — appends `?w=600&h=375&fit=crop&auto=format`.
  ///   * **Supabase** (`*.supabase.co/storage/v1/object/public/`) — rewrites the
  ///     path to the render endpoint and appends `?width=600&height=375&resize=cover`.
  static String thumbnailUrl(String url) {
    if (url.isEmpty) return url;

    // Unsplash — server-side resize via query params.
    if (url.contains('images.unsplash.com')) {
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}w=$_thumbWidth&h=$_thumbHeight&fit=crop&auto=format';
    }

    // Supabase — rewrite object/public → render/image/public for transform support.
    const supabasePrefix = 'supabase.co/storage/v1/object/public/';
    if (url.contains(supabasePrefix)) {
      final renderUrl = url.replaceFirst(
        '/object/public/',
        '/render/image/public/',
      );
      final separator = renderUrl.contains('?') ? '&' : '?';
      return '$renderUrl${separator}width=$_thumbWidth&height=$_thumbHeight&resize=cover';
    }

    // Unknown host — return the URL unchanged so no breakage occurs.
    return url;
  }
}
