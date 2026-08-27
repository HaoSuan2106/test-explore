import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/content_constraint.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';
import '../../models/hidden_place/recommended_place_model.dart';

enum PlaceStatus { verified, reportedClosed, underVoting }

class PlaceDetailsScreen extends StatefulWidget {
  final PlaceStatus status;
  final String? placeId;

  const PlaceDetailsScreen({
    super.key,
    this.status = PlaceStatus.verified,
    this.placeId,
  });

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  RecommendedPlaceModel? _place;
  bool _loading = true;
  String? _error;
  bool _mutating = false;

  void _setMutating(bool value) {
    if (!mounted) return;
    setState(() => _mutating = value);
  }

  @override
  void initState() {
    super.initState();
    // Defer the load until after the first frame: the provider calls
    // notifyListeners() synchronously in demo mode, which must not happen
    // while the widget tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final placeId = widget.placeId;
    if (placeId == null || placeId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No place selected.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = context.read<HiddenPlaceProvider>();
    // The place may already be in the provider's list; refresh it from the API.
    await provider.refreshPlace(placeId);

    if (!mounted) return;
    setState(() {
      _place = provider.getPlaceById(placeId);
      _loading = false;
      _error = _place == null ? 'This place could not be found.' : null;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  PlaceStatus get _effectiveStatus {
    final status = _place?.status;
    if (status == 'REPORTED_CLOSED') return PlaceStatus.reportedClosed;
    if (status == 'UNDER_VOTING') return PlaceStatus.underVoting;
    return PlaceStatus.verified;
  }

  Future<void> _confirmWithdraw() async {
    final placeId = _place?.id;
    if (placeId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Recommendation'),
        content: const Text(
            'Withdrawing this recommendation will remove it from community voting. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // REQ502_40: show a loading state while the withdrawal is processed.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final success = await context.read<HiddenPlaceProvider>().withdrawRecommendation(placeId);
    if (mounted) Navigator.of(context).pop(); // dismiss loading dialog
    if (!mounted) return;
    AppFeedback.show(context,
      message: success ? 'Recommendation withdrawn.' : 'Failed to withdraw the recommendation.',
      isSuccess: success,
    );
    if (success) {
      await context.read<HiddenPlaceProvider>().loadMyRecommendations();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleVerification({required bool verify}) async {
    final placeId = _place?.id;
    if (placeId == null || _mutating) return;
    _setMutating(true);
    final success = await context.read<HiddenPlaceProvider>().castVote(placeId, isVerify: verify);
    _setMutating(false);
    if (!mounted) return;
    AppFeedback.show(context,
      message: success
          ? (verify ? 'Your verification was recorded.' : 'Your verification was withdrawn.')
          : 'Failed to update your vote.',
      isSuccess: success,
    );
    if (success) {
      setState(() => _place = context.read<HiddenPlaceProvider>().getPlaceById(placeId));
    }
  }

  Future<void> _showReportSheet() async {
    final placeId = _place?.id;
    if (placeId == null || _mutating) return;
    _setMutating(true);
    final provider = context.read<HiddenPlaceProvider>();
    await provider.loadReportReasons();
    _setMutating(false);
    if (!mounted) return;
    final reasons = provider.reportReasons;

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

    if (selected == null || !mounted) return;
    _setMutating(true);
    final success = await provider.reportPlace(placeId, selected);
    _setMutating(false);
    if (!mounted) return;
    AppFeedback.show(context,
      message: success ? 'Your report was recorded.' : 'Failed to report this place.',
      isSuccess: success,
    );
    if (success) {
      setState(() => _place = context.read<HiddenPlaceProvider>().getPlaceById(placeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _effectiveStatus;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : ContentConstraint(
                  maxWidth: 800,
                  child: Stack(
                    children: [
                      Container(
                        height: 320,
                        color: const Color(0xFFE5E7EB),
                        child: Center(
                          child: Icon(
                            Icons.location_on,
                            size: 54,
                            color: status == PlaceStatus.reportedClosed
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: AppSpacing.containerMargin,
                        child: SafeArea(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.softElevation,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        top: 240,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
                            boxShadow: AppShadows.navElevation,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(_place!.name, style: AppTypography.headlineLg),
                                    ),
                                    if (status == PlaceStatus.underVoting)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: AppRadii.roundedSm,
                                        ),
                                        child: Text(
                                          _place!.category,
                                          style: AppTypography.labelSm.copyWith(color: AppColors.onPrimary),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.stackSm),
                                if (status == PlaceStatus.underVoting) ...[
                                  _buildVotingProgressCard(),
                                  const SizedBox(height: AppSpacing.stackLg),
                                  Text('About this Place', style: AppTypography.headlineMd.copyWith(fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(_place!.description.isEmpty ? 'No description provided.' : _place!.description,
                                      style: AppTypography.bodyMd),
                                  const SizedBox(height: AppSpacing.stackLg),
                                  _buildUnderVotingActions(),
                                ] else if (status == PlaceStatus.reportedClosed) ...[
                                  _buildReportedClosedBanner(),
                                  const SizedBox(height: AppSpacing.stackLg),
                                  _buildAddressCard(),
                                ] else ...[
                                  _buildVerifiedBadge(),
                                  const SizedBox(height: AppSpacing.stackLg),
                                  _buildAddressCard(),
                                ],
                                const SizedBox(height: AppSpacing.sectionGap),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.stackMd),
          Text(_error ?? 'Something went wrong.', style: AppTypography.bodyMd),
          const SizedBox(height: AppSpacing.stackMd),
          AppButton(
            text: 'Go Back',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingProgressCard() {
    final votes = _place!.currentVotes;
    final required = _place!.requiredVotes;
    final progress = required > 0 ? (votes / required).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutterMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
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
                  'Community Voting Progress',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: AppRadii.roundedSm,
                ),
                child: Text('$votes / $required Votes',
                    style: AppTypography.labelSm.copyWith(color: const Color(0xFF3F51B5))),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          ClipRRect(
            borderRadius: AppRadii.roundedFull,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.outline,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Needs ${required - votes} more verifications from local guides to earn the Verified Hidden Gem badge.',
            style: AppTypography.bodyMd.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderVotingActions() {
    final details = _place;
    if (details == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.isCurrentUserSubmitter)
          // REQ502_7: the Community Verification button is only shown for
          // eligible places — a submitter may not verify their own place.
          Container(
            padding: const EdgeInsets.all(AppSpacing.gutterMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: AppRadii.roundedLg,
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: Text(
                    'This is your own recommendation. Other community members will verify it.',
                    style: AppTypography.bodyMd,
                  ),
                ),
              ],
            ),
          )
        else if (details.isVerifiedByCurrentUser) ...[
          AppButton(
            text: 'Withdraw My Verification',
            icon: Icons.undo,
            variant: AppButtonVariant.outline,
            onPressed: () => _toggleVerification(verify: false),
            isLoading: _mutating,
            height: 44,
          ),
        ] else ...[
          AppButton(
            text: 'Verify this Place',
            icon: Icons.how_to_vote,
            onPressed: () => _toggleVerification(verify: true),
            isLoading: _mutating,
            height: 44,
          ),
        ],
        const SizedBox(height: AppSpacing.stackMd),
        if (!details.isCurrentUserSubmitter) ...[
          if (details.isReportedByCurrentUser)
            // Final scope: report is recorded and cannot be withdrawn; show a
            // non-actionable indicator instead of a withdraw action.
            AppButton(
              text: 'Reported',
              icon: Icons.flag_outlined,
              variant: AppButtonVariant.outline,
              onPressed: null,
              height: 44,
            )
          else
            AppButton(
              text: 'Report this Place',
              icon: Icons.flag_outlined,
              variant: AppButtonVariant.destructive,
              onPressed: _showReportSheet,
              height: 44,
            ),
        ],
        const SizedBox(height: AppSpacing.stackMd),
        if (details.isCurrentUserSubmitter)
          AppButton(
            text: 'Withdraw Recommendation',
            icon: Icons.delete_outline,
            variant: AppButtonVariant.outline,
            onPressed: _confirmWithdraw,
            height: 44,
          ),
      ],
    );
  }

  Widget _buildReportedClosedBanner() {
    return Container(
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
            child: Text(
              'This recommendation was removed after receiving too many community reports. Information may be inaccurate.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutterMd),
      decoration: BoxDecoration(
        color: AppColors.successContainer,
        borderRadius: AppRadii.roundedLg,
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: AppColors.success),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Text(
              'Verified Hidden Gem — confirmed by ${_place!.currentVotes} community verifications.',
              style: AppTypography.bodyMd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutterMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadii.roundedLg,
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Text(_place!.address, style: AppTypography.bodyMd),
          ),
        ],
      ),
    );
  }
}