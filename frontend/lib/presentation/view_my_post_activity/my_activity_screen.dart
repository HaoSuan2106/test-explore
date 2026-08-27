import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../providers/post_review/post_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/content_constraint.dart';
import '../navigation/app_navigation.dart';

class MyActivityScreen extends StatefulWidget {
  final int initialTabIndex;

  const MyActivityScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PostProvider>().loadMyActivity();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'My Activity', showBack: true),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: AppTypography.labelLg,
                tabs: const [
                  Tab(text: 'My Posts'),
                  Tab(text: 'My Comments'),
                  Tab(text: 'Reported Posts'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsTab(),
                    _buildCommentsTab(),
                    _buildReportedTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    final provider = context.watch<PostProvider>();
    final posts = provider.userPosts;

    if (provider.isActivityLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty && provider.activityErrorMessage != null) {
      return _buildErrorState(provider.activityErrorMessage!, () {
        context.read<PostProvider>().loadMyActivity();
      });
    }

    if (posts.isEmpty) {
      return _buildEmptyState(
        'No posts published yet',
        'Your shared travel stories will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      itemCount: posts.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.gutterMd),
        child: _buildPostCard(posts[i]),
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    return InkWell(
      onTap: () => AppNavigation.toPostDetails(context, postId: post.id),
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
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  backgroundImage: NetworkImage(post.authorAvatar),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: AppTypography.labelLg),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              post.location,
                              style: AppTypography.labelSm,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildMyPostMenu(context, post),
              ],
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Text(
              post.title,
              style: AppTypography.headlineMd.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              post.description,
              style: AppTypography.bodyMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Row(
              children: [
                const Icon(Icons.favorite, size: 18, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${post.likes}',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.gutterMd),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentsCount}',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.share_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPostMenu(BuildContext context, PostModel post) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
      onSelected: (val) {
        if (val == 'edit') {
          AppNavigation.toEditPost(context, postId: post.id);
        } else if (val == 'delete') {
          _confirmDeletePost(context, post);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text('Edit Post'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete Post', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDeletePost(BuildContext context, PostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEECEB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Color(0xFFE53935), size: 30),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Text(
              'Delete Post',
              style: AppTypography.headlineMd.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Are you sure you want to permanently delete this post? This action cannot be undone.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.stackLg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel', style: AppTypography.labelLg.copyWith(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
                      final success =
                      await context.read<PostProvider>().deletePost(post.id);
                      if (!context.mounted) return;
                      if (success) {
                        // D-05: close the loading screen and show a green
                        // success banner; the user stays on My Activity.
                        Navigator.of(context).pop(); // leave loading screen
                        AppFeedback.show(context,
                          message: 'Post deleted successfully.',
                          isSuccess: true,
                        );
                      } else {
                        Navigator.of(context).pop(); // leave loading screen
                        AppFeedback.show(context,
                          message: 'Failed to delete the post. Please try again.',
                          isSuccess: false,
                        );
                      }
                    },
                    child: Text('Delete', style: AppTypography.labelLg.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsTab() {
    final provider = context.watch<PostProvider>();
    final comments = provider.userComments;

    if (provider.isActivityLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (comments.isEmpty && provider.activityErrorMessage != null) {
      return _buildErrorState(provider.activityErrorMessage!, () {
        context.read<PostProvider>().loadMyActivity();
      });
    }

    if (comments.isEmpty) {
      return _buildEmptyState(
        'No comments written yet',
        'Your community interactions will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      itemCount: comments.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.gutterMd),
        child: _buildCommentCard(comments[i]),
      ),
    );
  }

  Widget _buildCommentCard(UserCommentItem comment) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gutterMd),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadii.roundedLg,
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: AppRadii.roundedSm,
              ),
              child: Text(
                'Commented on: ${comment.postTitle}',
                style: AppTypography.labelSm.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('“', style: TextStyle(fontSize: 24, color: AppColors.primary, height: 1)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(comment.content, style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${comment.createdAt.day}/${comment.createdAt.month}/${comment.createdAt.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm,
                  ),
                ),
                const SizedBox(width: AppSpacing.stackMd),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      // LEGACY screen: route-based comment editing was removed
                      // (comment editing is inline in Post Details). No-op to
                      // keep this unreferenced screen compiling.
                      onTap: () {},
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('Edit', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gutterMd),
                    GestureDetector(
                      onTap: () => _confirmDeleteComment(context, comment.commentId),
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text('Delete', style: AppTypography.labelSm.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteComment(BuildContext context, String commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEECEB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Color(0xFFE53935), size: 30),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Text(
              'Delete this comment?',
              style: AppTypography.headlineMd.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'This comment will be permanently deleted.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.stackLg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel', style: AppTypography.labelLg.copyWith(color: AppColors.textPrimary)),
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final success = await context
                          .read<PostProvider>()
                          .deleteComment(commentId);
                      if (!context.mounted) return;
                      AppFeedback.show(context,
                        message: success
                            ? 'Comment deleted successfully.'
                            : 'Failed to delete the comment. Please try again.',
                        isSuccess: success,
                      );
                    },
                    child: Text('Delete', style: AppTypography.labelLg.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportedTab() {
    final provider = context.watch<PostProvider>();
    final reports = provider.userReports;

    if (provider.isActivityLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reports.isEmpty && provider.activityErrorMessage != null) {
      return _buildErrorState(provider.activityErrorMessage!, () {
        context.read<PostProvider>().loadMyActivity();
      });
    }

    if (reports.isEmpty) {
      return _buildEmptyState(
        'No reports submitted',
        'Posts you flag for review will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      itemCount: reports.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.gutterMd),
        child: _buildReportedCard(reports[i]),
      ),
    );
  }

  Widget _buildReportedCard(UserReportItem report) {
    return InkWell(
      // LEGACY screen: the Report Details route was removed (report status now
      // lives inside Post Details). No-op to keep this screen compiling.
      onTap: () {},
      borderRadius: AppRadii.roundedLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gutterMd),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadii.roundedLg,
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    report.postTitle,
                    style: AppTypography.headlineMd.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
            Text('Posted by ${report.postedBy}', style: AppTypography.bodyMd),
            const SizedBox(height: AppSpacing.stackMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withValues(alpha: 0.5),
                      borderRadius: AppRadii.roundedSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag, size: 14, color: AppColors.error),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'You Reported This',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.stackMd),
                Text(
                  '${report.submittedAt.day}/${report.submittedAt.month}/${report.submittedAt.year}',
                  style: AppTypography.labelSm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 56, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.stackMd),
          Text(title, style: AppTypography.headlineMd),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.bodyMd),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 56, color: AppColors.error),
          const SizedBox(height: AppSpacing.stackMd),
          Text('Could not load your activity', style: AppTypography.headlineMd),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, style: AppTypography.bodyMd, textAlign: TextAlign.center),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          AppButton(
            text: 'Retry',
            icon: Icons.refresh,
            variant: AppButtonVariant.outline,
            height: 44,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}