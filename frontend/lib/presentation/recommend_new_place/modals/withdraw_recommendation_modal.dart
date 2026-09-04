import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_feedback.dart';
import '../../../../providers/hidden_place/hidden_place_provider.dart';

class WithdrawRecommendationModal extends StatefulWidget {
  final String placeId;

  const WithdrawRecommendationModal({
    super.key,
    this.placeId = '',
  });

  @override
  State<WithdrawRecommendationModal> createState() => _WithdrawRecommendationModalState();
}

class _WithdrawRecommendationModalState extends State<WithdrawRecommendationModal> {
  bool _confirmed = false;
  bool _mutating = false;

  @override
  Widget build(BuildContext context) {
    final placeProvider = context.watch<HiddenPlaceProvider>();
    final place = placeProvider.getPlaceById(widget.placeId);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      // SingleChildScrollView keeps every action reachable on short screens
      // (the modals can be taller than the viewport on 320px-wide devices).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: AppRadii.roundedFull,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Withdraw Recommendation',
                      style: AppTypography.headlineMd),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Container(
              padding: const EdgeInsets.all(AppSpacing.gutterMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: AppRadii.roundedLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place?.name ?? 'Recommended place', style: AppTypography.headlineMd.copyWith(fontSize: 16)),
                  if (place?.latitude != null && place?.longitude != null)
                    Text('📍 ${place!.latitude!.toStringAsFixed(5)}, ${place.longitude!.toStringAsFixed(5)}',
                        style: AppTypography.labelSm),
                  const SizedBox(height: 6),
                  if (place != null)
                    Text(place.description.isEmpty ? 'No description provided.' : place.description,
                        style: AppTypography.bodyMd),
                  const SizedBox(height: 6),
                  Text(
                    place == null
                        ? 'Place not found.'
                        : 'Status: ${place.isUnderVoting ? 'Under Voting' : place.status} '
                        '(Submitted on ${place.submittedAt.toLocal().day}/${place.submittedAt.toLocal().month}/${place.submittedAt.toLocal().year})',
                    style: AppTypography.labelSm.copyWith(
                      color: place?.isUnderVoting == true ? AppColors.warning : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Container(
              padding: const EdgeInsets.all(AppSpacing.gutterMd),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.4),
                borderRadius: AppRadii.roundedLg,
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Warning', style: AppTypography.labelLg.copyWith(color: AppColors.error)),
                        const SizedBox(height: 2),
                        Text(
                          'Withdrawing this recommendation will remove it from community voting. All current votes will be forfeited and this action cannot be undone.',
                          style: AppTypography.bodyMd.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            // Material with a transparent color so the ListTile's ink splash is
            // not hidden by the modal's DecoratedBox background.
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: _confirmed,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                title: Text(
                  'I understand that withdrawing this recommendation cannot be undone.',
                  style: AppTypography.bodyMd.copyWith(fontSize: 12),
                ),
                onChanged: (val) => setState(() => _confirmed = val ?? false),
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Cancel',
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.gutterMd),
                Expanded(
                  child: AppButton(
                    text: 'Withdraw',
                    variant: AppButtonVariant.destructive,
                    isLoading: _mutating,
                    onPressed: _confirmed && widget.placeId.isNotEmpty && !_mutating
                        ? () async {
                      setState(() => _mutating = true);
                      final provider = context.read<HiddenPlaceProvider>();
                      final success = await provider.withdrawRecommendation(widget.placeId);
                      if (!context.mounted) return;
                      if (success) {
                        // Refresh so the withdrawn place leaves the list (REQ502_39).
                        await provider.loadMyRecommendations();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _mutating = false);
                        AppFeedback.show(context,
                          message: provider.errorMessage ?? 'Failed to withdraw the recommendation. Please try again.',
                          isSuccess: false,
                        );
                      }
                    }
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackMd),
          ],
        ),
      ),
    );
  }
}