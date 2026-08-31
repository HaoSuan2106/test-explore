import 'dart:io';

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// A photo thumbnail that renders either:
///  - an already-persisted public URL (http/https) — never re-downloaded, or
///  - a locally picked device file path (uploaded only at submission time).
///
/// This keeps edit-mode behavior correct: existing photos coming from the
/// server (recommended_places.photos_json) are URLs, while freshly picked
/// photos are local `File` paths. Both are rendered the same way, and any
/// unavailable source falls back to a broken-image placeholder — never a crash.
class PhotoThumb extends StatelessWidget {
  final String path;
  final double width;
  final double height;

  const PhotoThumb({
    super.key,
    required this.path,
    required this.width,
    required this.height,
  });

  /// True when [path] is an absolute http/https URL rather than a local file.
  static bool isRemote(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (isRemote(path)) {
      image = Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    } else {
      image = Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return ClipRRect(
      borderRadius: AppRadii.roundedDefault,
      child: image,
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceCard,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.textSecondary,
      ),
    );
  }
}
