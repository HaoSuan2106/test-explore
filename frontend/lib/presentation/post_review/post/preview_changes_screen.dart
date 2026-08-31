import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_header.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_feedback.dart';
import '../../../../widgets/content_constraint.dart';
import '../../../../providers/post_review/post_provider.dart';
import '../../../../providers/auth_profile/profile_provider.dart';

class PreviewChangesScreen extends StatelessWidget {
  final String? postId;

  const PreviewChangesScreen({super.key, this.postId});

  @override
  Widget build(BuildContext context) {
    // Targeted subscriptions: only the draft fields, draft version, profile
    // and loading flag drive this preview. A like/save elsewhere must not
    // rebuild the preview screen.
    final profile = context.select<ProfileProvider, dynamic>((p) => p.profile);
    final postProvider = context.read<PostProvider>();
    context.select<PostProvider, int>((p) => p.draftVersion);
    final isSaving = context.select<PostProvider, bool>((p) => p.isLoading);
    final username =
        (profile?.username != null && profile!.username.isNotEmpty)
            ? profile.username
            : 'Traveler';
    final title = postProvider.draftTitle.isNotEmpty ? postProvider.draftTitle : 'Untitled Post';
    final description = postProvider.draftDescription.isNotEmpty
        ? postProvider.draftDescription
        : 'No description provided.';
    final location = postProvider.draftLocation;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'Preview Changes', showBack: true),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 600,
          child: Column(
            children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFE8EAF6),
              child: Row(
                children: [
                  const Icon(Icons.visibility, size: 18, color: Color(0xFF3F51B5)),
                  const SizedBox(width: 8),
                  Text(
                    'Previewing post before publishing',
                    style: AppTypography.labelSm.copyWith(color: const Color(0xFF3F51B5)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.containerMargin),
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
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.surfaceCard,
                            child: Icon(Icons.person, size: 20, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelLg,
                                ),
                                Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSm,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppTypography.headlineMd),
                              const SizedBox(height: AppSpacing.stackSm),
                              Text(
                                description,
                                style: AppTypography.bodyMd,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      Row(
                        children: [
                          const Icon(Icons.favorite, size: 18, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('0', style: AppTypography.labelSm),
                          const SizedBox(width: 16),
                          const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('0', style: AppTypography.labelSm),
                          const Spacer(),
                          const Icon(Icons.share_outlined, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.containerMargin),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Keep Editing',
                      icon: Icons.edit,
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutterMd),
                  Expanded(
                    child: AppButton(
                      text: 'Publish Changes',
                      icon: Icons.publish,
                      isLoading: isSaving,
                      onPressed: () async {
                        final provider = context.read<PostProvider>();
                        // Post title is compulsory (business decision H-4);
                        // block publishing when the title is missing.
                        if (provider.draftTitle.trim().isEmpty) {
                          AppFeedback.show(context, message: 'Post title is required.', isSuccess: false);
                          return;
                        }
                        final postId = await provider.publishDraft(postId: this.postId);
                        if (!context.mounted) return;
                        if (postId != null) {
                          AppFeedback.show(context, message: 'Post published successfully.', isSuccess: true);
                          if (this.postId != null) {
                            // Edit flow: return to Post Details.
                            Navigator.of(context).pop(); // pop Preview
                            Navigator.of(context).pop(); // pop Edit
                          } else {
                            // Create flow: return to the Feed (root shell).
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        } else {
                          AppFeedback.show(context,
                            message: provider.errorMessage ?? 'Failed to save the post. Please try again.',
                            isSuccess: false,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}