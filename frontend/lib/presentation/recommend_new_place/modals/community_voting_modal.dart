import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/hidden_place/recommended_place_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';

enum VotingState { unvoted, verified, reported }

class CommunityVotingBottomSheet extends StatefulWidget {
  final VoidCallback onDetailsPressed;
  final String placeId;

  const CommunityVotingBottomSheet({
    super.key,
    required this.onDetailsPressed,
    this.placeId = '',
  });

  @override
  State<CommunityVotingBottomSheet> createState() => _CommunityVotingBottomSheetState();
}

class _CommunityVotingBottomSheetState extends State<CommunityVotingBottomSheet> {
  VotingState _votingState = VotingState.unvoted;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize state from the current place data (e.g. if already verified).
    final place = context.read<HiddenPlaceProvider>().getPlaceById(widget.placeId);
    if (place != null && place.isVerifiedByCurrentUser) {
      _votingState = VotingState.verified;
    }
  }

  RecommendedPlaceModel? _place() =>
      context.read<HiddenPlaceProvider>().getPlaceById(widget.placeId);

  Future<void> _verify() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final success = await context
        .read<HiddenPlaceProvider>()
        .castVote(widget.placeId, isVerify: true);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      setState(() => _votingState = VotingState.verified);
    } else {
      AppFeedback.show(context,
        message: context.read<HiddenPlaceProvider>().errorMessage ?? 'Failed to verify this place.',
        isSuccess: false,
      );
    }
  }

  Future<void> _reportPlace() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final provider = context.read<HiddenPlaceProvider>();
    await provider.loadReportReasons();
    if (!mounted) return;
    final reasons = provider.reportReasons;

    // Let the user pick a predefined report reason (REQ502_22) instead of
    // hardcoding one.
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
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
            Text('Report this place', style: AppTypography.headlineMd),
            const SizedBox(height: 4),
            Text('Why are you reporting this recommendation?', style: AppTypography.bodyMd),
            const SizedBox(height: AppSpacing.stackMd),
            ...reasons.map((reason) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, color: AppColors.error),
              title: Text(reason, style: AppTypography.bodyMd),
              onTap: () => Navigator.of(ctx).pop(reason),
            )),
            const SizedBox(height: AppSpacing.stackMd),
          ],
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (selected == null) return;

    setState(() => _isSubmitting = true);
    final success = await provider.reportPlace(widget.placeId, selected);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      setState(() => _votingState = VotingState.reported);
    } else {
      AppFeedback.show(context,
        message: provider.errorMessage ?? 'Failed to report this place.',
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = _place();
    final placeName = place?.name ?? 'Recommended place';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
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
              Text('Community voting', style: AppTypography.headlineMd),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackMd),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.gutterMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: AppRadii.roundedLg,
            ),
            child: Column(
              children: [
                Text(placeName, style: AppTypography.headlineMd.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                if (place != null)
                  Text('Verified by ${place.currentVotes} of ${place.requiredVotes} community members',
                      style: AppTypography.bodyMd),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          if (_votingState == VotingState.unvoted) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.gutterMd),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECE7),
                borderRadius: AppRadii.roundedLg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Text(
                      'Help us build a better travel community. Verify this place if it\'s worth visiting or report it if the information is incorrect.',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),
            Text('What would you like to do?', style: AppTypography.labelLg),
            const SizedBox(height: AppSpacing.stackMd),
            _buildOptionCard(
              title: 'Verify Place',
              subtitle: 'This place exists and is worth recommending to other travelers.',
              icon: Icons.check_circle,
              iconColor: AppColors.success,
              bgColor: AppColors.background,
              borderColor: AppColors.outlineVariant,
              onTap: _verify,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            _buildOptionCard(
              title: 'Report Place',
              subtitle: 'This place information is incorrect, closed, or not worth visiting.',
              icon: Icons.flag,
              iconColor: AppColors.error,
              bgColor: AppColors.background,
              borderColor: AppColors.outlineVariant,
              onTap: _reportPlace,
            ),
            const SizedBox(height: AppSpacing.stackLg),
            Center(
              child: Text(
                'You can only vote once for each recommendation',
                style: AppTypography.labelSm,
              ),
            ),
          ] else if (_votingState == VotingState.verified) ...[
            _buildOptionCard(
              title: 'Verify Place (Selected)',
              subtitle: 'This place exists and is worth recommending to other travelers.',
              icon: Icons.check_circle,
              iconColor: AppColors.success,
              bgColor: AppColors.successContainer.withValues(alpha: 0.5),
              borderColor: AppColors.success,
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.stackMd),
            _buildStatusBanner('Thank you! You verified this place.', AppColors.success),
            const SizedBox(height: AppSpacing.stackMd),
            AppButton(
              text: 'View Verified Place Details',
              suffixIcon: Icons.arrow_forward,
              onPressed: widget.onDetailsPressed,
              variant: AppButtonVariant.primary,
            ),
          ] else if (_votingState == VotingState.reported) ...[
            _buildOptionCard(
              title: 'Report Place (Selected)',
              subtitle: 'This place information is incorrect, closed, or not worth visiting.',
              icon: Icons.flag,
              iconColor: AppColors.error,
              bgColor: AppColors.errorContainer.withValues(alpha: 0.5),
              borderColor: AppColors.error,
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.stackMd),
            _buildStatusBanner('Thank you! You reported this place.', AppColors.error),
            const SizedBox(height: AppSpacing.stackMd),
            AppButton(
              text: 'View Unverified Place Details',
              suffixIcon: Icons.arrow_forward,
              onPressed: widget.onDetailsPressed,
              variant: AppButtonVariant.destructive,
            ),
          ],
          const SizedBox(height: AppSpacing.stackMd),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isSubmitting ? null : onTap,
      borderRadius: AppRadii.roundedLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gutterMd),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadii.roundedLg,
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.stackMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelLg),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.bodyMd.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String message, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.roundedXl,
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.onPrimary, size: 20),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}