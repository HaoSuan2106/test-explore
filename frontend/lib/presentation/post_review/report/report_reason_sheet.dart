import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/post_review/post_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../navigation/app_navigation.dart';

/// Bottom sheet that lets the user pick a predefined report reason, submits
/// the report via the API, and navigates to the Report Details screen.
class ReportReasonSheet extends StatefulWidget {
  final String postId;

  const ReportReasonSheet({super.key, required this.postId});

  static Future<void> show(BuildContext context, {required String postId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => ReportReasonSheet(postId: postId),
    );
  }

  @override
  State<ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<ReportReasonSheet> {
  bool _submitting = false;
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PostProvider>();
      if (provider.reportReasons.isEmpty) {
        provider.loadReportReasons();
      }
    });
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null || reason.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    final provider = context.read<PostProvider>();
    final reportId = await provider.submitReport(widget.postId, reason);
    if (!mounted) return;
    if (reportId == null) {
      AppFeedback.show(context,
          message: 'Failed to submit the report. Please try again.',
          isSuccess: false);
      setState(() => _submitting = false);
      return;
    }
    Navigator.of(context).pop();
    // Report success lands on the shared Thank You screen; the report status
    // is shown inside Post Details (no separate Report Details screen).
    AppNavigation.toReportSubmittedSuccess(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostProvider>();
    final reasons = provider.reportReasons;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          20,
          AppSpacing.containerMargin,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report Post',
                  style: AppTypography.headlineMd.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Why are you reporting this post? Your report is private.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (reasons.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...reasons.map((reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedReason = reason),
                      borderRadius: AppRadii.roundedDefault,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedReason == reason
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.surfaceCard,
                          borderRadius: AppRadii.roundedDefault,
                          border: Border.all(
                            color: _selectedReason == reason
                                ? AppColors.primary
                                : AppColors.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedReason == reason
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: _selectedReason == reason
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(reason, style: AppTypography.bodyMd),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
            const SizedBox(height: AppSpacing.stackLg),
            AppButton(
              text: 'Submit Report',
              icon: Icons.flag_outlined,
              isLoading: _submitting,
              onPressed: _selectedReason == null ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
