import 'package:flutter/widgets.dart';

/// Process-wide memory-pressure handler for the Post / Community module.
///
/// When Android (or the host) sends a genuine memory-pressure notification,
/// [ImageCacheGuard] trims Flutter's **decoded image cache** — the in-memory
/// cache of decoded bitmap pixels that accumulates as the user scrolls the
/// Post Feed / opens Post Details / swipes the gallery.
///
/// Why this is needed:
///   Under sustained image-heavy POST/COMMUNITY usage, decoded images
///   accumulate in [PaintingBinding.instance.imageCache] until the Android
///   per-app heap cap (~256 MB) is reached. At that point ART full GC pauses
///   (~940 ms) block the UI thread → massive skipped frames → multi-second
///   Davey jank. Trimming the decoded-image cache on a genuine memory-pressure
///   signal keeps the heap below the cap.
///
/// Design decisions (minimum-risk):
///   * [clear] only — evicts decoded images that are NOT currently displayed.
///     Live images (visible on screen) are retained, so the user sees NO
///     flashing and NO unnecessary network reloads. The bulk of the cache is
///     off-screen images, so [clear] frees most memory without any UX impact.
///   * Nothing is cleared per-frame, per-scroll, or in build(). Eviction only
///     happens when the system explicitly reports memory pressure.
///   * The disk cache (`DefaultCacheManager`) is NOT touched. Only the decoded
///     in-memory bitmap cache is trimmed, so cached network bytes survive.
///   * Registration is done exactly once in `main()`; no duplicate observers.
///
/// See: POST_COMMUNITY_SOLUTION_PLAN.md Part 6 (Memory Cache Design).
class ImageCacheGuard with WidgetsBindingObserver {
  ImageCacheGuard._();

  /// The single app-wide instance.
  static final ImageCacheGuard instance = ImageCacheGuard._();

  /// Register the guard once at app startup. Safe to call multiple times:
  /// a static flag prevents duplicate observer registration on hot reload /
  /// rebuild / repeated calls.
  static void init() {
    if (_isRegistered) return;
    _isRegistered = true;
    WidgetsBinding.instance.addObserver(instance);
    // Priority 3 (least invasive): bound the decoded-image cache so its
    // memory cannot accumulate unbounded. Flutter's default is 100 MB /
    // 1000 entries. Capping to 50 MB / 200 entries makes LRU eviction kick
    // in much earlier, so the decoded-bitmap working set stays small. Images
    // that are evicted simply re-decode from the disk cache when next shown —
    // no data loss, no blank screens, no custom CacheManager required.
    // NOTE: This cap bounds the DART/native image cache, but the 256 MB OOM
    // is on the ART Java heap. The cap alone does not prevent the OOM — the
    // ART heap is dominated by the Google Maps SDK (IndexedStack, always alive
    // on the Explore tab, out of scope).
    final cache = PaintingBinding.instance.imageCache;
    if (cache.maximumSizeBytes > kMaxImageCacheBytes) {
      cache.maximumSizeBytes = kMaxImageCacheBytes;
    }
    if (cache.maximumSize > kMaxImageCacheEntries) {
      cache.maximumSize = kMaxImageCacheEntries;
    }
  }

  /// Decoded-image cache byte cap (50 MB, was 100 MB default).
  static const int kMaxImageCacheBytes = 50 * 1024 * 1024;

  /// Decoded-image cache entry cap (200 entries, was 1000 default).
  static const int kMaxImageCacheEntries = 200;

  static bool _isRegistered = false;

  /// Whether a trim has been performed (exposed for tests/diagnostics).
  bool didTrim = false;

  /// Last time a trim happened (exposed for tests/diagnostics).
  DateTime? lastTrimTime;

  /// Number of trims performed (exposed for tests/diagnostics).
  int trimCount = 0;

  @override
  void didHaveMemoryPressure() {
    trimDecodedImageCache();
  }

  /// Trim Flutter's decoded image cache. Safe to call directly for
  /// diagnostics, but in production it is only invoked by the system
  /// memory-pressure notification ([didHaveMemoryPressure]).
  void trimDecodedImageCache() {
    // Synchronous but O(1)-ish: the ImageCache clear just drops map entries
    // (the heavy freeing is deferred to the GC, off the UI thread). This is
    // the standard Flutter pattern and does not block the UI thread.
    PaintingBinding.instance.imageCache.clear();
    didTrim = true;
    trimCount++;
    lastTrimTime = DateTime.now();
  }
}
