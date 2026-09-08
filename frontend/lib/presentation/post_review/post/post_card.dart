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
///
/// Action surface (required design):
/// - Engagement footer row: ❤️ like | 💬 comment count | (...) More menu.
/// - The (...) menu is the SINGLE action entry point:
///     owner       -> Edit / Delete
///     normal user -> Bookmark / Report
/// - The duplicate bottom Edit/Delete buttons are removed; the menu reuses
///   the same onEdit/onDelete callbacks.
/// - Comment is NOT part of the More menu: both owner and normal user comment
///   through the existing comment UI (Post Details composer).
/// - Relationship labels are shown as compact chips. The info icon opens the
///   full Post Label Guide explaining every label.
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
                      if (post.location.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      _buildRelationshipBadges(context, isCommented),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _buildCardPopupMenu(),
              ],
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

            if (gallery.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.stackMd),
              PostImageGalleryView(
                images: gallery,
              ),
            ],

            // Reported by the current user → comment UI (the "You commented"
            // preview) is hidden along with the footer actions.
            if (!post.isReportedByCurrentUser)
              ..._buildContextualStatusBox(isCommented, myCommentPreview),

            const SizedBox(height: AppSpacing.stackMd),

            // Reported by the current user → ALL interaction affordances are
            // hidden (Like/likes, Comment count, Bookmark/Save). Only the
            // content and Reported markers remain; nothing here is tappable.
            if (!post.isReportedByCurrentUser)
              _buildEngagementFooter(isLikeInFlight),
          ],
        ),
      ),
    );
  }

  /// Builds compact relationship labels in canonical priority order.
  /// Priority controls ordering now; it no longer hides valid relationships.
  Widget _buildRelationshipBadges(
    BuildContext context,
    bool isCommented,
  ) {
    // After a report, interaction-state labels are interaction affordances:
    // hide Liked / Commented / Saved. My Post and Reported remain.
    final hideInteractionLabels = post.isReportedByCurrentUser;
    final labels = <_RelationshipLabel>[];

    if (isOwner) {
      labels.add(
        const _RelationshipLabel(
          label: 'My Post',
          description: 'You created this post.',
          color: AppColors.success,
          icon: Icons.person_outline,
        ),
      );
    }

    if (post.isReportedByCurrentUser) {
      labels.add(
        const _RelationshipLabel(
          label: 'Reported Post',
          description: 'You reported this post.',
          color: AppColors.error,
          icon: Icons.flag_outlined,
        ),
      );
    }

    if (isCommented && !hideInteractionLabels) {
      labels.add(
        const _RelationshipLabel(
          label: 'You Commented',
          description: 'You commented on this post.',
          color: Color(0xFF5C6BC0),
          icon: Icons.chat_bubble_outline,
        ),
      );
    }

    if (post.isLiked && !hideInteractionLabels) {
      labels.add(
        const _RelationshipLabel(
          label: 'Liked',
          description: 'You liked this post.',
          color: AppColors.primary,
          icon: Icons.favorite,
        ),
      );
    }

    if (post.isSaved && !hideInteractionLabels) {
      labels.add(
        const _RelationshipLabel(
          label: 'Saved',
          description: 'You saved this post.',
          color: Color(0xFF7B61FF),
          icon: Icons.bookmark,
        ),
      );
    }

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible = labels.take(2).toList();
    final hiddenCount = labels.length - visible.length;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in visible) _buildRelationshipChip(item),
                if (hiddenCount > 0)
                  InkWell(
                    onTap: () => _showAllRelationships(context, labels),
                    borderRadius: AppRadii.roundedFull,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: AppRadii.roundedFull,
                        border: Border.all(
                          color: AppColors.outlineVariant,
                        ),
                      ),
                      child: Text(
                        '+$hiddenCount',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipChip(_RelationshipLabel item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.10),
        borderRadius: AppRadii.roundedFull,
        border: Border.all(color: item.color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 12, color: item.color),
          const SizedBox(width: 4),
          Text(
            item.label,
            style: AppTypography.labelSm.copyWith(
              color: item.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllRelationships(
    BuildContext context,
    List<_RelationshipLabel> labels,
  ) {
    _showPostLabelGuide(context, labels);
  }

  void _showPostLabelGuide(
    BuildContext context,
    List<_RelationshipLabel> labels,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Post Label Guide',
                          style: AppTypography.headlineMd.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                  for (final item in labels)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 36,
                            child: Icon(
                              item.icon,
                              size: 24,
                              color: item.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: AppTypography.labelLg.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.description,
                                  style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.stackSm),
                  Text(
                    'A post can have more than one label. Several labels can appear on the same post.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Contextual status box placed below the description for relevant filtered
  /// posts. Shows a light-red "Status: Under Review" for reported posts and a
  /// light-orange "You commented:" box for commented posts. Owners can comment
  /// on their own posts, so they get the commented box like everyone else.
  List<Widget> _buildContextualStatusBox(bool isCommented, String? myCommentPreview) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // This preview represents the current user's own
                    // comment. If the current user also owns the post,
                    // the comment is an OWNER comment.
                    if (isOwner)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.10),
                          borderRadius: AppRadii.roundedFull,
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          'OWNER',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    Text(
                      preview != null
                          ? isOwner
                              ? 'Owner commented: "$preview"'
                              : 'You commented: "$preview"'
                          : isOwner
                              ? 'Owner commented on this post.'
                              : 'You commented on this post.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSm.copyWith(
                        color: const Color(0xFF8A5200),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return const [];
  }

  /// Engagement footer with like toggle, comments count, and the single
  /// More (...) action entry point.
  /// Engagement footer: Like | Comment count | Save/Bookmark.
  /// The More (...) menu is at the top-right of the card.
  Widget _buildEngagementFooter(bool isLikeInFlight) {
    return Row(
      children: [
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          post.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20,
                          color: post.isLiked
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

        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
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
        ),

        const Spacer(),

        // SAVE / BOOKMARK — pinned to the far right.
        if (!isOwner)
          InkWell(
            onTap: post.isReportedByCurrentUser ? null : onSave,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 4,
              ),
              child: Icon(
                post.isSaved
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                size: 22,
                color: post.isSaved
                    ? const Color(0xFF7B61FF)
                    : AppColors.textMuted,
              ),
            ),
          ),
              ],
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
          // Reported by the current user: the More menu offers ONLY the
          // disabled Reported marker — no Save/Unsave, no second Report.
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

class _RelationshipLabel {
  const _RelationshipLabel({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String label;
  final String description;
  final Color color;
  final IconData icon;
}
