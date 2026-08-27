import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_button.dart';
import '../../../../providers/post_review/post_provider.dart';
import '../../../../utils/time_format.dart';
import '../../../../widgets/app_feedback.dart';

class EditCommentBottomSheet extends StatefulWidget {
  final String commentId;
  final String? initialContent;
  final String authorName;

  const EditCommentBottomSheet({
    super.key,
    required this.commentId,
    this.initialContent,
    this.authorName = 'Aisyah Nur',
  });

  @override
  State<EditCommentBottomSheet> createState() => _EditCommentBottomSheetState();
}

class _EditCommentBottomSheetState extends State<EditCommentBottomSheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String _displayTimeAgo = '';
  String _postTitle = '';

  @override
  void initState() {
    super.initState();
    String content = widget.initialContent ?? '';
    final comments = context.read<PostProvider>().userComments;
    try {
      final comment = comments.firstWhere((c) => c.commentId == widget.commentId);
      if (content.isEmpty) {
        content = comment.content;
      }
      _displayTimeAgo = timeAgo(comment.createdAt);
      _postTitle = comment.postTitle;
    } catch (_) {}
    _controller = TextEditingController(text: content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.containerMargin,
        right: AppSpacing.containerMargin,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: 'Edit Comment' + 'Cancel'
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Comment',
                  style: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tagged Post Reference
            Text(
              'Commented on:',
              style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              _postTitle.isNotEmpty ? _postTitle : 'E2E Manual Post by Alice',
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),

            // Text Input Box with Character Counter
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: AppRadii.roundedLg,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    maxLength: 100,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
                    style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary, height: 1.4),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_controller.text.length}/100',
                    style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),

            // Save Changes Primary Action Button
            AppButton(
              text: 'Save Changes',
              isLoading: _isSaving,
              onPressed: () async {
                if (_isSaving) return;
                final content = _controller.text.trim();
                if (content.isEmpty) {
                  AppFeedback.show(context, message: 'Comment cannot be blank.', isSuccess: false);
                  return;
                }
                setState(() => _isSaving = true);
                final success = await context
                    .read<PostProvider>()
                    .editComment(widget.commentId, content);
                setState(() => _isSaving = false);
                if (!context.mounted) return;
                if (success) {
                  Navigator.of(context).pop();
                } else {
                  AppFeedback.show(context, message: 'Failed to update the comment. Please try again.', isSuccess: false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EditCommentScreen extends StatelessWidget {
  final String commentId;
  final String? initialContent;

  const EditCommentScreen({
    super.key,
    required this.commentId,
    this.initialContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: EditCommentBottomSheet(
          commentId: commentId,
          initialContent: initialContent,
        ),
      ),
    );
  }
}