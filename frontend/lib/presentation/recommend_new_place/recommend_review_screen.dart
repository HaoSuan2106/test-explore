import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/content_constraint.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';
import '../navigation/app_navigation.dart';
import 'photo_thumbnail.dart';
import 'recommend_place_draft.dart';
import 'wizard_step_indicator.dart';

/// STEP 4 of the Recommend Place wizard — Review & Submit.
///
/// Shows the full recommendation (details + location) and submits it through
/// `HiddenPlaceProvider.submitRecommendation`. On success it replaces itself
/// with the Success screen; on failure it shows an inline feedback message.
class RecommendReviewScreen extends StatefulWidget {
  final RecommendPlaceDraft draft;

  const RecommendReviewScreen({super.key, required this.draft});

  @override
  State<RecommendReviewScreen> createState() =>
      _RecommendReviewScreenState();
}

class _RecommendReviewScreenState extends State<RecommendReviewScreen> {
  bool _submitting = false;

  Future<void> _onSubmit() async {
    final draft = widget.draft;
    if (_submitting) return;
    setState(() => _submitting = true);

    final provider = context.read<HiddenPlaceProvider>();
    final String? id;

    if (draft.editingSubmissionId != null) {
      // Edit mode: update the existing recommendation.
      id = await provider.updateRecommendation(
        submissionId: draft.editingSubmissionId!,
        name: draft.name,
        primaryType: draft.primaryType,
        description: draft.description,
        latitude: draft.latitude ?? 0,
        longitude: draft.longitude ?? 0,
        priceLevel: draft.priceLevel,
        photoPaths: draft.photoPaths.isNotEmpty ? draft.photoPaths : null,
      );
    } else {
      // Create mode: submit a new recommendation.
      id = await provider.submitRecommendation(
        name: draft.name,
        primaryType: draft.primaryType,
        description: draft.description,
        latitude: draft.latitude ?? 0,
        longitude: draft.longitude ?? 0,
        priceLevel: draft.priceLevel,
        photoPaths: draft.photoPaths.isNotEmpty ? draft.photoPaths : null,
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (id != null) {
      // Read the authoritative verification count from the provider (which
      // reloaded the list inside submitRecommendation/updateRecommendation).
      final count = provider.getPlaceById(id)?.currentVotes ?? 0;

      // Replace the review step so going back from Success skips it, and carry
      // the submission id so Success can link straight to its Details. Mark the
      // terminal as an UPDATE when we were editing, so the success copy and the
      // return flow match the operation that actually completed.
      AppNavigation.toRecommendationSuccess(
        context,
        submissionId: id,
        isUpdate: draft.editingSubmissionId != null,
        verificationCount: count,
      );
    } else {
      AppFeedback.show(context,
        message: provider.errorMessage ??
            'Failed to submit your recommendation.',
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Review & Submit',
        showBack: true,
      ),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.containerMargin, 4, AppSpacing.containerMargin, 0),
                child: const WizardStepIndicator(current: 4),
              ),
              const SizedBox(height: AppSpacing.stackSm),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.stackMd),
                      Text(
                        'Review Your Recommendation',
                        style: AppTypography.headlineMd,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check everything before you submit.',
                        style: AppTypography.bodyMd.copyWith(
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.stackLg),

                      _buildSummaryRow(
                        icon: Icons.storefront_outlined,
                        label: 'Place Name',
                        value: draft.name,
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      _buildSummaryRow(
                        icon: Icons.category_outlined,
                        label: 'Primary Type',
                        value: draft.primaryType,
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      _buildSummaryRow(
                        icon: Icons.notes,
                        label: 'Description',
                        value: draft.description,
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      if (draft.priceLevel != null) ...[
                        _buildSummaryRow(
                          icon: Icons.paid_outlined,
                          label: 'Price Level',
                          value: _priceLevelLabel(draft.priceLevel!),
                        ),
                        const SizedBox(height: AppSpacing.stackSm),
                      ],
                      _buildSummaryRow(
                        icon: Icons.my_location,
                        label: 'Coordinates',
                        value: (draft.latitude != null &&
                                draft.longitude != null)
                            ? '${draft.latitude!.toStringAsFixed(6)}, '
                                '${draft.longitude!.toStringAsFixed(6)}'
                            : 'Not selected',
                      ),
                      if (draft.photoPaths.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.stackMd),
                        Text(
                          'Photos (${draft.photoPaths.length})',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPhotoGrid(draft.photoPaths),
                      ],
                      const SizedBox(height: AppSpacing.stackLg),
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Edit Details',
                            icon: Icons.edit_outlined,
                            variant: AppButtonVariant.outline,
                            onPressed: () =>
                                AppNavigation.toEditRecommendDetails(
                                    context, draft: draft),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.gutterMd),
                        Expanded(
                          child: AppButton(
                            text: 'Edit Location',
                            icon: Icons.map_outlined,
                            variant: AppButtonVariant.outline,
                            onPressed: () =>
                                AppNavigation.toEditRecommendLocation(
                                    context, draft: draft),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: 'Submit Recommendation',
                        icon: Icons.send,
                        isLoading: _submitting,
                        onPressed: _onSubmit,
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

  /// Price-level label, kept in sync with Step 1's `_priceLevelLabel`.
  String _priceLevelLabel(int value) {
    switch (value) {
      case 0:
        return 'Free';

      case 1:
        return r'$';

      case 2:
        return r'$$';

      case 3:
        return r'$$$';

      case 4:
        return r'$$$$';

      default:
        return value.toString();
    }
  }


  /// Read-only photo thumbnails for the review. Uses the same local paths
  /// carried in the draft (uploaded only at submission). Invalid/corrupt files
  /// fall back to a broken-image placeholder — never a crash.
  Widget _buildPhotoGrid(List<String> paths) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return PhotoThumb(
            path: paths[index],
            width: 96,
            height: 96,
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}