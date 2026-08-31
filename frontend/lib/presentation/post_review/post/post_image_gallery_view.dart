import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import 'post_image_sizes.dart';

/// Feed image preview for a post card.
///
/// The Post Feed shows a SINGLE representative image (the first) per card,
/// decoded at the small thumbnail size ([PostImageSizes.feedThumbnailWidth/
/// Height]). Multi-image posts show a `1/N` count badge overlay so users know
/// more photos exist; the full swipeable gallery lives in Post Details (which
/// decodes at higher resolution).
///
/// This deliberately does NOT create a [PageView] per card — a nested
/// scrollable viewport per PostCard was the dominant UI-thread cost in the
/// feed (many cards × PageView gesture/physics/children overhead). Only one
/// [CachedNetworkImage] is ever built per card here.
class PostImageGalleryView extends StatelessWidget {
  final List<String> images;

  const PostImageGalleryView({
    super.key,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    final images = this.images;

    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: AppRadii.roundedDefault,
        child: Container(
          height: 200,
          color: AppColors.surfaceVariant,
          child: const Icon(
            Icons.image,
            size: 40,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    final total = images.length;

    return ClipRRect(
      borderRadius: AppRadii.roundedDefault,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: images.first,
              fit: BoxFit.cover,
              memCacheWidth: PostImageSizes.feedThumbnailWidth,
              memCacheHeight: PostImageSizes.feedThumbnailHeight,
              maxWidthDiskCache: PostImageSizes.feedThumbnailWidth,
              maxHeightDiskCache: PostImageSizes.feedThumbnailHeight,
              useOldImageOnUrlChange: true,
              placeholder: (_, _) => Container(
                color: AppColors.surfaceVariant,
                child: const Icon(
                  Icons.image,
                  size: 40,
                  color: AppColors.textMuted,
                ),
              ),
              errorWidget: (_, _, _) => Container(
                color: AppColors.surfaceVariant,
                child: const Icon(
                  Icons.image,
                  size: 40,
                  color: AppColors.textMuted,
                ),
              ),
            ),

            // Count badge: signals additional photos; full gallery is in
            // Post Details. The badge is only built when needed (total > 1).
            if (total > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: AppRadii.roundedFull,
                  ),
                  child: Text(
                    '1/$total',
                    style: AppTypography.labelSm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
