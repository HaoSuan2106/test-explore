import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../providers/post_review/post_provider.dart';
import '../../../providers/auth_profile/profile_provider.dart';
import '../navigation/app_navigation.dart';
import '../post_review/comment/edit_comment_screen.dart';
import '../post_review/report/report_reason_sheet.dart';
import '../post_review/post/post_image_sizes.dart';
import '../post_review/post/edit_post_screen.dart';
import '../../../utils/time_format.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/content_constraint.dart';

class PostDetailsScreen extends StatefulWidget {
  final String postId;

  const PostDetailsScreen({
    super.key,
    this.postId = 'post-001',
  });

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _likeAnimController;
  late final Animation<double> _likeScaleAnim;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _likeAnimController,
      curve: Curves.easeInOut,
    ));
    // Load the post details + comments from the API on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PostProvider>().loadPostDetails(widget.postId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final provider = context.read<PostProvider>();
    final text = _commentController.text.trim();
    if (text.isEmpty || provider.isCommentSubmitting) return;

    final success = await provider.addComment(widget.postId, text);
    if (!mounted) return;
    if (success) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
      AppFeedback.show(context, message: 'Comment added successfully.');
    } else {
      AppFeedback.show(context, message: 'Failed to add the comment. Please try again.', isSuccess: false);
    }
  }

  void _confirmDeletePost(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Post', style: AppTypography.headlineMd.copyWith(fontSize: 18)),
        content: Text(
          'Are you sure you want to permanently delete this post? This action cannot be undone.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTypography.labelLg.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Full-screen loading while the deletion runs (shared
              // status architecture), then land on the Post Deleted
              // success screen.
              AppNavigation.toStatusLoading(
                context,
                heading: 'Deleting Post',
                message:
                    'We are safely deleting your post. Please wait a moment.',
              );
              final success = await context.read<PostProvider>().deletePost(widget.postId);
              if (!context.mounted) return;
              if (success) {
                // D-05: close the loading screen, show the green success
                // banner, then pop the Post Details screen so the user
                // returns to the screen they came from (feed / My Activity).
                // The banner is presented via the root ScaffoldMessenger, so
                // it survives the navigation pops. Delete is owner-only, so
                // a reported-post (reporter) detail context can never reach
                // this flow, and no forced redirect into My Reports happens.
                Navigator.of(context).pop(); // leave loading screen
                AppFeedback.show(context,
                  message: 'Post deleted successfully.',
                  isSuccess: true,
                );
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop(); // leave Post Details
                } else {
                  AppNavigation.toMain(context); // fallback: no back route
                }
              } else {
                Navigator.of(context).pop(); // leave loading screen
                AppFeedback.show(context,
                  message: 'Failed to delete the post. Please try again.',
                  isSuccess: false,
                );
              }
            },
            child: Text('Delete', style: AppTypography.labelLg.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showPostHeaderMenu(BuildContext context, bool isOwner) {
    final isReported =
        context.read<PostProvider>().getPostById(widget.postId)?.isReportedByCurrentUser ?? false;
    final isSaved =
        context.read<PostProvider>().getPostById(widget.postId)?.isSaved ?? false;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
                title: Text('Edit Post', style: AppTypography.bodyMd),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final provider = context.read<PostProvider>();
                  final result = await AppNavigation.toEditPost<PostEditResult>(
                      context, postId: widget.postId);
                  if (!mounted) return;
                  if (result == PostEditResult.updated) {
                    await provider.loadPostDetails(widget.postId);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('Delete Post', style: AppTypography.bodyMd.copyWith(color: AppColors.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeletePost(context);
                },
              ),
            ] else if (isReported) ...[
              // Final scope: a report is recorded and cannot be withdrawn, so
              // the reported post shows a non-actionable indicator only.
              ListTile(
                enabled: false,
                leading: const Icon(Icons.flag_outlined, color: AppColors.textSecondary),
                title: Text('Reported', style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary)),
              ),
            ] else ...[
              ListTile(
                leading: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: AppColors.textPrimary,
                ),
                title: Text(isSaved ? 'Unsave Post' : 'Save Post', style: AppTypography.bodyMd),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _toggleSavePost(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.error),
                title: Text('Report Post', style: AppTypography.bodyMd.copyWith(color: AppColors.error)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final result =
                      await ReportReasonSheet.show(context, postId: widget.postId);
                  if (!mounted) return;
                  if (result == ReportResult.submitted && context.mounted) {
                    AppNavigation.toReportSubmittedSuccess(context);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSavePost(BuildContext context) async {
    final success =
        await context.read<PostProvider>().toggleSavePost(widget.postId);
    if (!context.mounted) return;
    if (success) {
      final isSaved =
          context.read<PostProvider>().getPostById(widget.postId)?.isSaved ?? false;
      AppFeedback.show(context,
          message: isSaved ? 'Post saved.' : 'Post unsaved.', isSuccess: true);
    } else {
      AppFeedback.show(context,
          message: 'Failed to update the saved state. Please try again.',
          isSuccess: false);
    }
  }

  /// Shares the post by copying a shareable text to the clipboard (no backend
  /// dependency in Phase 1).
  Future<void> _sharePost() async {
    final post = context.read<PostProvider>().getPostById(widget.postId);
    final text = post == null
        ? 'Check out this community post on ExploreMY!'
        : 'Check out "${post.title}" at ${post.location} on ExploreMY!';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppFeedback.show(context,
        message: 'Post details copied to clipboard.', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    // Targeted subscriptions: rebuild only when this post's data changes or
    // loading/error state flips. Unrelated provider notifications (like a
    // like on a different post) do NOT rebuild this screen.
    final postProvider = context.read<PostProvider>();
    final isLoading = context.select<PostProvider, bool>((p) => p.isLoading);
    final errorMessage = context.select<PostProvider, String?>((p) => p.errorMessage);
    context.select<PostProvider, int>((p) => p.postRevision(widget.postId));
    final currentUserId = context.select<ProfileProvider, String?>(
        (p) => p.profile?.userId.toString());
    final post = postProvider.getPostById(widget.postId);
    final comments = postProvider.getCommentsForPost(widget.postId);

    if (isLoading && post == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AppHeader(title: 'Post Details', showBack: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (post == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AppHeader(title: 'Post Details', showBack: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                errorMessage != null
                    ? Icons.cloud_off_outlined
                    : Icons.search_off,
                size: 64,
                color: errorMessage != null
                    ? AppColors.error
                    : AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                errorMessage != null
                    ? 'Could not load this post'
                    : 'Post not found or has been deleted.',
                style: AppTypography.headlineMd,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  errorMessage ?? '',
                  style: AppTypography.bodyMd,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              AppButton(
                text: 'Retry',
                icon: Icons.refresh,
                variant: AppButtonVariant.outline,
                height: 44,
                onPressed: () => context
                    .read<PostProvider>()
                    .loadPostDetails(widget.postId),
              ),
            ],
          ),
        ),
      );
    }

    final isOwner = post.authorId == currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Post Details',
        showBack: true,
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
              onPressed: () async {
                final provider = context.read<PostProvider>();
                final result = await AppNavigation.toEditPost<PostEditResult>(
                    context, postId: widget.postId);
                if (!mounted) return;
                if (result == PostEditResult.updated) {
                  await provider.loadPostDetails(widget.postId);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onPressed: () => _showPostHeaderMenu(context, isOwner),
          ),
        ],
      ),
      bottomNavigationBar: isOwner
          ? _buildOwnerBottomBar()
          : post.isReportedByCurrentUser
              ? _buildReportedBottomBar()
              : _buildBottomComposer(),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Header section (everything before comments) — built once.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.containerMargin,
                  AppSpacing.gutterMd,
                  AppSpacing.containerMargin,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author row matching reference
                      _buildAuthorHeader(post),
                      const SizedBox(height: AppSpacing.stackLg),

                      // Saved indicator (SAVED state: the current user saved
                      // this post — visible within Post Details, consistent
                      // with the "My Post / You Commented / Reported" chips
                      // on the feed).
                      if (!isOwner && post.isSaved) ...[
                        _buildSavedIndicator(),
                        const SizedBox(height: AppSpacing.stackMd),
                      ],

                      // Post Title & Description
                      _buildPostContent(post),
                      const SizedBox(height: AppSpacing.stackLg),

                      // Report indicator (REPORTED flow: the user is shown
                      // that their report was recorded. No admin review
                      // wording and no withdraw action per the final scope.)
                      if (post.isReportedByCurrentUser) ...[
                        _buildReportStatusBanner(),
                        const SizedBox(height: AppSpacing.stackLg),
                      ],

                      // Uploaded images (REQ501_2)
                      if (post.galleryImages.isNotEmpty) ...[
                        _buildPostImages(post.galleryImages),
                        const SizedBox(height: AppSpacing.stackLg),
                      ],

                      // Engagement row (Likes, Comments, Share)
                      _buildEngagementRow(post, comments.length),
                      const SizedBox(height: AppSpacing.gutterMd),

                      // Comments header
                      _buildCommentsHeader(comments.length),
                      const SizedBox(height: AppSpacing.stackMd),
                    ],
                  ),
                ),
              ),

              // Comment Cards — lazily built via SliverList.builder so only
              // visible comments incur widget/build cost.
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin,
                ),
                sliver: comments.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.stackLg,
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 40,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: AppSpacing.stackMd),
                              Text(
                                'No comments yet',
                                style: AppTypography.bodyMd.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Be the first to start the conversation.',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppSpacing.stackMd,
                    ),
                    child: _buildCommentCard(context, comments[i]),
                  ),
                ),
              ),

              // Bottom spacing (replaces the SizedBox at the end of the
              // original Column — now outside the lazy list).
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.sectionGap),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(color: const Color(0xFFF0C36D), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, size: 18, color: Color(0xFFB26A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You reported this post.',
              style: AppTypography.bodyMd.copyWith(color: const Color(0xFF8A5300)),
            ),
          ),
        ],
      ),
    );
  }

  /// Inline chip indicating the current user saved this post (SAVED state).
  Widget _buildSavedIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF7B61FF).withValues(alpha: 0.10),
          borderRadius: AppRadii.roundedFull,
          border: Border.all(
            color: const Color(0xFF7B61FF).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark, size: 13, color: Color(0xFF7B61FF)),
            SizedBox(width: 4),
            Text(
              'Saved',
              style: TextStyle(
                color: Color(0xFF7B61FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorHeader(PostModel post) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFF05D38),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 28),
        ),
        const SizedBox(width: AppSpacing.stackMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Tagged: ${post.location}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent(PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.title,
          style: AppTypography.headlineLg.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        Text(
          post.description,
          style: AppTypography.bodyMd.copyWith(
            fontSize: 14,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Uploaded image gallery (REQ501_2: details include uploaded images).
  /// Details screen decodes at higher resolution than the feed thumbnail.
  Widget _buildPostImages(List<String> imageUrls) {
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: AppRadii.roundedDefault,
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: CachedNetworkImage(
            imageUrl: imageUrls.first,
            fit: BoxFit.cover,
            memCacheWidth: PostImageSizes.detailsWidth,
            memCacheHeight: PostImageSizes.detailsHeight,
            placeholder: (_, _) => Container(
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.image, size: 40, color: AppColors.textMuted),
            ),
            errorWidget: (_, _, _) => Container(
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.image, size: 40, color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.gutterMd),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: AppRadii.roundedDefault,
          child: CachedNetworkImage(
            imageUrl: imageUrls[i],
            width: 340,
            fit: BoxFit.cover,
            memCacheWidth: PostImageSizes.detailsGalleryWidth,
            memCacheHeight: PostImageSizes.detailsGalleryHeight,
            placeholder: (_, _) => Container(
              width: 340,
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.image, size: 40, color: AppColors.textMuted),
            ),
            errorWidget: (_, _, _) => Container(
              width: 340,
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.image, size: 40, color: AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementRow(PostModel post, int commentsCount) {
    final postProvider = context.read<PostProvider>();
    return Row(
      children: [
        InkWell(
          onTap: post.isReportedByCurrentUser || postProvider.isLikeInFlight(widget.postId)
              ? null
              : _toggleLike,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                postProvider.isLikeInFlight(widget.postId)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : AnimatedBuilder(
                        animation: _likeAnimController,
                        builder: (context, child) => Transform.scale(
                          scale: _likeScaleAnim.value,
                          child: child,
                        ),
                        child: Icon(
                          post.isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: post.isReportedByCurrentUser
                              ? AppColors.textMuted
                              : post.isLiked
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                        ),
                      ),
                const SizedBox(width: 6),
                Text(
                  '${post.likes}',
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.stackLg),
        const Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.textPrimary),
        const SizedBox(width: 6),
        Text(
          '$commentsCount',
          style: AppTypography.labelLg.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: _sharePost,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.share_outlined, size: 19, color: AppColors.textPrimary),
                const SizedBox(width: 4),
                Text(
                  'Share',
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsHeader(int count) {
    return Row(
      children: [
        Text(
          'Comments ($count)',
          style: AppTypography.headlineMd.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentCard(BuildContext context, UserCommentItem comment) {
    // Read (not watch): the screen build() already subscribes to the profile
    // userId, so per-comment watch subscriptions are unnecessary rebuilds.
    final currentUserId = context.read<ProfileProvider>().profile?.userId.toString();
    // Owner of comment can Edit/Delete
    final isCommentOwner = comment.authorId.toString() == currentUserId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Color(0xFF64748B), size: 24),
        ),
        const SizedBox(width: AppSpacing.stackSm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.gutterMd),
            decoration: BoxDecoration(
              color: isCommentOwner ? const Color(0xFFF0FDF4) : AppColors.surfaceCard,
              borderRadius: AppRadii.roundedLg,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLg.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeAgo(comment.createdAt),
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 4),
                        _buildCommentPopupMenu(context, comment, isCommentOwner),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.content,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteComment(BuildContext context, UserCommentItem comment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to permanently delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await context.read<PostProvider>().deleteComment(comment.commentId);
              if (!context.mounted) return;
              AppFeedback.show(context,
                message: success
                    ? 'Comment deleted successfully.'
                    : 'Failed to delete the comment. Please try again.',
                isSuccess: success,
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentPopupMenu(BuildContext context, UserCommentItem comment, bool isOwner) {
    if (!isOwner) return const SizedBox.shrink();

    // REQ: reporters with an active report on the post are view-only — they
    // cannot edit/delete their own comments on that post either.
    final isReported =
        context.read<PostProvider>().getPostById(widget.postId)?.isReportedByCurrentUser ?? false;
    if (isReported) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
      onSelected: (val) {
        if (val == 'edit') {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => EditCommentBottomSheet(
              commentId: comment.commentId,
              initialContent: comment.content,
              authorName: comment.authorName,
            ),
          );
        } else if (val == 'delete') {
          _confirmDeleteComment(context, comment);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLike() async {
    final wasLiked =
        context.read<PostProvider>().getPostById(widget.postId)?.isLiked ?? false;
    final success = await context.read<PostProvider>().togglePostLike(widget.postId);
    if (!mounted) return;
    if (success) {
      // Heart-pop animation + approved solid-color toast.
      _likeAnimController.forward(from: 0);
      _showLikeToast(context, liked: !wasLiked);
    } else {
      AppFeedback.show(context, message: 'Failed to update the reaction. Please try again.', isSuccess: false);
    }
  }

  /// Approved solid-color toast (3s) for the "You liked this post!" /
  /// "You unliked this post." micro-interaction.
  void _showLikeToast(BuildContext context, {required bool liked}) {
    AppFeedback.show(context,
        message: liked ? 'You liked this post!' : 'You unliked this post.');
  }

  /// Bottom bar for the post owner: keeps the like action but hides the
  /// comment input (users must not comment on their own post).
  Widget _buildOwnerBottomBar() {
    final postProvider = context.read<PostProvider>();
    final post = postProvider.getPostById(widget.postId);
    final isLiked = post?.isLiked ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        boxShadow: AppShadows.navElevation,
        border: Border(top: BorderSide(color: AppColors.outline, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: const Color(0xFFF05D38),
                size: 24,
              ),
              onPressed: _toggleLike,
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Text(
                'You cannot comment on your own post.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom bar for the reporter: like button disabled + view-only message.
  Widget _buildReportedBottomBar() {
    final postProvider = context.read<PostProvider>();
    final post = postProvider.getPostById(widget.postId);
    final isLiked = post?.isLiked ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        boxShadow: AppShadows.navElevation,
        border: Border(top: BorderSide(color: AppColors.outline, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Text(
                'You have reported this post and are in view-only mode.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomComposer() {
    final postProvider = context.read<PostProvider>();
    final post = postProvider.getPostById(widget.postId);
    final isLiked = post?.isLiked ?? false;
    // Targeted subscription: rebuild only the send-button spinner when the
    // comment-submitting flag flips, not the whole screen.
    final isCommentSubmitting =
        context.select<PostProvider, bool>((p) => p.isCommentSubmitting);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        boxShadow: AppShadows.navElevation,
        border: Border(top: BorderSide(color: AppColors.outline, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: const Color(0xFFF05D38),
                size: 24,
              ),
              onPressed: _toggleLike,
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: TextField(
                  controller: _commentController,
                  style: AppTypography.bodyMd,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    hintText: 'Add a thought...',
                    border: InputBorder.none,
                    isDense: true,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            IconButton(
              icon: isCommentSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
              onPressed: _submitComment,
            ),
          ],
        ),
      ),
    );
  }
}