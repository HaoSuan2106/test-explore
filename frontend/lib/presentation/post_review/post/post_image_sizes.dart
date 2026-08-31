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
}
