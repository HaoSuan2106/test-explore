import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../providers/post_review/post_provider.dart';
import '../navigation/app_navigation.dart';

class ReportDetailsScreen extends StatelessWidget {
  final String reportId;
  final String postId;

  const ReportDetailsScreen({
    super.key,
    required this.reportId,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostProvider>();
    // Prefer the live report record; fall back to the post if available.
    UserReportItem? report;
    try {
      report = provider.userReports.firstWhere((r) => r.reportId == reportId);
    } catch (_) {
      report = null;
    }
    final post = provider.getPostById(postId);

    final reportReason = report?.reason ?? 'Unknown reason';
    final submissionDate = report != null
        ? '${report.submittedAt.day}/${report.submittedAt.month}/${report.submittedAt.year}'
        : '—';
    final authorName = post?.authorName ?? 'Unknown';
    final location = post?.location ?? 'Unknown location';
    final postTitle = post?.title ?? 'Reported post';
    final postDescription = post?.description ?? '';
    final imageUrl = (post != null && post.imageUrl.isNotEmpty)
        ? post.imageUrl
        : '';
    final likes = post?.likes ?? 0;
    final comments = post?.commentsCount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Report Details',
        showBack: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.containerMargin,
            vertical: AppSpacing.stackSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportReasonCard(reportReason: reportReason, submissionDate: submissionDate),
              const SizedBox(height: AppSpacing.stackLg),
              Text(
                'Reported Post Content',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              _buildReportedPostPreviewCard(context,
                  authorName: authorName,
                  location: location,
                  postTitle: postTitle,
                  postDescription: postDescription,
                  imageUrl: imageUrl,
                  likes: likes,
                  comments: comments),
              const SizedBox(height: AppSpacing.sectionGap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportReasonCard({required String reportReason, required String submissionDate}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gutterMd),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.4),
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Text(
                'Your Selected Report Reason',
                style: AppTypography.labelLg.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reportReason,
            style: AppTypography.headlineMd.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                'Submitted on $submissionDate',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportedPostPreviewCard(
    BuildContext context, {
    required String authorName,
    required String location,
    required String postTitle,
    required String postDescription,
    required String imageUrl,
    required int likes,
    required int comments,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.softElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutterMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.surfaceCard,
                      child: const Icon(
                        Icons.person,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.stackSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: AppTypography.labelLg.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                                  location,
                                  style: AppTypography.labelSm,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.stackMd),
                ClipRRect(
                  borderRadius: AppRadii.roundedDefault,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: imageUrl.isEmpty
                        ? Container(
                            color: AppColors.surfaceVariant,
                            child: const Icon(
                              Icons.image,
                              size: 40,
                              color: AppColors.textMuted,
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.surfaceVariant,
                              child: const Icon(
                                Icons.image,
                                size: 40,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                Text(
                  postTitle,
                  style: AppTypography.headlineMd.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  postDescription,
                  style: AppTypography.bodyMd,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.stackMd),
                Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$likes',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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
                      '$comments',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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
          const Divider(height: 1, color: AppColors.outline),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutterMd,
              vertical: 10,
            ),
            child: AppButton(
              text: 'View Details',
              suffixIcon: Icons.arrow_forward,
              variant: AppButtonVariant.outline,
              height: 44,
              onPressed: () => AppNavigation.toPostDetails(context, postId: postId),
            ),
          ),
        ],
      ),
    );
  }
}