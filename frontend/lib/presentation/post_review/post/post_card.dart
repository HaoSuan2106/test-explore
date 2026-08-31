import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/post_review/post_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/time_format.dart';
import 'post_image_gallery_view.dart';
import 'post_image_sizes.dart';

/// Post card widget for the Post Feed.
///
/// Presentation only — all user actions are forwarded to the parent screen
/// through callbacks, so [PostCard] never owns provider logic or navigation.
/// Providers remain the single source of truth. The card subscribes only to
/// *its own* post revision (via `context.select`), so a like/save/comment on
/// this post rebuilds this card without rebuilding the rest of the feed.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isOwner,
    required this.onTap,
    required this.onReaction,
    required this.onSave,
    required this.onReport,
    required this.onEdit,
    required this.onDelete,
  });

  final PostModel post;

  /// Whether the current user is the post author.
  final bool isOwner;

  /// Opens the post details screen.
  final VoidCallback onTap;

  /// Toggles the like/reaction on this post.
  final VoidCallback onReaction;

  /// Toggles the saved (bookmark) state on this post.
  final VoidCallback onSave;

  /// Opens the report reason sheet for this post.
  final VoidCallback onReport;

  /// Opens the edit-post screen for this post.
  final VoidCallback onEdit;

  /// Prompts the delete confirmation dialog for this post.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Subscribe to this post's own revision only. When a like/save/comment
    // mutates THIS post, only this card rebuilds (Post B/C/D stay untouched).
    context.select<PostProvider, int>((p) => p.postRevision(post.id));
    final postProvider = context.read<PostProvider>();
    final isCommented = postProvider.commentedPostIds.contains(post.id);
    final isLikeInFlight = postProvider.isLikeInFlight(post.id);
    final isSaveInFlight = postProvider.isSaveInFlight(post.id);
    final myCommentPreview = postProvider.commentPreviewFor(post.id);

    final gallery = post.galleryImages.isNotEmpty
        ? post.galleryImages
        : (post.imageUrl.isNotEmpty
        ? [post.imageUrl]
        : const <String>[]);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.roundedLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gutterMd),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadii.roundedLg,
          border: Border.all(color: AppColors.outline),
          boxShadow: AppShadows.softElevation,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header:
            // avatar -> author/time/location -> relationship badge -> menu.
            // Badge sits on separate row to prevent horizontal overflow.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadii.roundedFull,
                  child: CachedNetworkImage(
                    imageUrl: post.authorAvatar,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    memCacheWidth: PostImageSizes.avatar,
                    memCacheHeight: PostImageSizes.avatar,
                    useOldImageOnUrlChange: true,
                    errorWidget: (_, _, _) => const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelLg.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeAgo(post.createdAt),
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildPrimaryBadge(isCommented),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _buildCardPopupMenu(),
              ],
            ),

            const SizedBox(height: AppSpacing.stackMd),

            // Horizontal swipeable image gallery.
            // 1/N indicator appears when post has multiple images.
            PostImageGalleryView(
              images: gallery,
            ),

            const SizedBox(height: AppSpacing.stackMd),

            Text(
              post.title,
              style: AppTypography.headlineMd.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: AppSpacing.stackSm),

            Text(
              post.description,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            ..._buildContextualStatusBox(isCommented, myCommentPreview),

            const SizedBox(height: AppSpacing.stackMd),

            _buildEngagementFooter(isLikeInFlight),

            const SizedBox(height: AppSpacing.stackSm),

            _buildActionFooter(isCommented, isSaveInFlight),
          ],
        ),
      ),
    );
  }

  /// Single primary relationship badge at the top right of the card,
  /// prioritizing Owner > Reported > Commented > Saved.
  Widget _buildPrimaryBadge(bool isCommented) {
    final String? label;
    Color color;
    IconData icon;
    if (isOwner) {
      label = 'My Post';
      color = AppColors.success;
      icon = Icons.person_outline;
    } else if (post.isReportedByCurrentUser) {
      label = 'Reported Post';
      color = AppColors.error;
      icon = Icons.flag_outlined;
    } else if (isCommented) {
      label = 'You Commented';
      color = const Color(0xFF5C6BC0);
      icon = Icons.chat_bubble_outline;
    } else if (post.isSaved) {
      label = 'Saved';
      color = const Color(0xFF7B61FF);
      icon = Icons.bookmark;
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.roundedFull,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Contextual status box placed below the description for relevant filtered
  /// posts. Shows a light-red "Status: Under Review" for reported posts and a
  /// light-orange "You commented:" box for commented posts.
  List<Widget> _buildContextualStatusBox(bool isCommented, String? myCommentPreview) {
    if (isOwner) return const [];
    if (post.isReportedByCurrentUser) {
      return [
        const SizedBox(height: AppSpacing.stackMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: AppRadii.roundedDefault,
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status: Under Review',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    if (isCommented) {
      final preview = myCommentPreview;
      return [
        const SizedBox(height: AppSpacing.stackMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E5),
            borderRadius: AppRadii.roundedDefault,
            border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFFB26A00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  preview != null
                      ? 'You commented: "$preview"'
                      : 'You commented on this post.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm.copyWith(
                    color: const Color(0xFF8A5200),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return const [];
  }

  /// Engagement footer with like toggle, comments count, and share.
  Widget _buildEngagementFooter(bool isLikeInFlight) {
    return Row(
      children: [
        // LIKE
        Expanded(
          child: InkWell(
            onTap: post.isReportedByCurrentUser
                ? null
                : isLikeInFlight
                ? null
                : onReaction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isLikeInFlight
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    post.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 18,
                    color: post.isReportedByCurrentUser
                        ? AppColors.textMuted
                        : post.isLiked
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${post.likes}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // COMMENTS
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // const Icon(
                //   Icons.chat_bubble_outline,
                //   size: 18,
                //   color: AppColors.textMuted,
                // ),
                const SizedBox(width: 6),
                Text(
                  '${post.commentsCount}',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // SHARE
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.share_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Share',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Context-aware action footer: Edit/Delete for owners, View Post for
  /// interacted posts, and Bookmark for standard discover posts.
  Widget _buildActionFooter(bool isCommented, bool isSaveInFlight) {
    final isInteracted = !isOwner &&
        (post.isReportedByCurrentUser || isCommented);
    if (isOwner) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      );
    }
    if (isInteracted) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
          label: const Text('View Post'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.outlineVariant),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }
    // Standard discover post — Bookmark (save/unsave)
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isSaveInFlight ? null : onSave,
        icon: isSaveInFlight
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
              ),
        label: Text(post.isSaved ? 'Saved' : 'Bookmark'),
        style: OutlinedButton.styleFrom(
          foregroundColor: post.isSaved
              ? const Color(0xFF7B61FF)
              : AppColors.primary,
          side: BorderSide(
            color: (post.isSaved
                ? const Color(0xFF7B61FF)
                : AppColors.primary)
                .withValues(alpha: 0.4),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCardPopupMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
      onSelected: (val) {
        if (val == 'edit') {
          onEdit();
        } else if (val == 'delete') {
          onDelete();
        } else if (val == 'report') {
          onReport();
        } else if (val == 'save') {
          onSave();
        } else if (val == 'unsave') {
          onSave();
        }
      },
      itemBuilder: (context) => [
        if (isOwner) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ] else if (post.isReportedByCurrentUser) ...[
          const PopupMenuItem(
            enabled: false,
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Reported', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ] else ...[
          PopupMenuItem(
            value: post.isSaved ? 'unsave' : 'save',
            child: Row(
              children: [
                Icon(
                  post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(post.isSaved ? 'Unsave' : 'Save'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text('Report', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
