import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/content_constraint.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';
import '../../models/hidden_place/recommended_place_model.dart';
import '../navigation/app_navigation.dart';

class MyRecommendedPlacesScreen extends StatefulWidget {
  const MyRecommendedPlacesScreen({super.key});

  @override
  State<MyRecommendedPlacesScreen> createState() => _MyRecommendedPlacesScreenState();
}

class _MyRecommendedPlacesScreenState extends State<MyRecommendedPlacesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HiddenPlaceProvider>().loadMyRecommendations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeProvider = context.watch<HiddenPlaceProvider>();
    final places = placeProvider.userRecommendations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'My Recommended Places',
        showBack: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppNavigation.toRecommendPlace(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.add,
          size: 32,
        ),
      ),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildStat(Icons.location_on, '${placeProvider.totalCount}', 'Total', AppColors.primary),
                    ),
                    _buildDivider(),
                    Expanded(
                      child: _buildStat(Icons.how_to_vote, '${placeProvider.underVotingCount}', 'Under Voting', AppColors.warning),
                    ),
                    _buildDivider(),
                    Expanded(
                      child: _buildStat(Icons.check_circle, '${placeProvider.verifiedCount}', 'Verified', AppColors.success),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),
              Text('Your Place Submissions', style: AppTypography.headlineMd.copyWith(fontSize: 16)),
              const SizedBox(height: AppSpacing.stackSm),
              if (placeProvider.isLoading && places.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (placeProvider.errorMessage != null && places.isEmpty)
                _buildLoadErrorState(placeProvider.errorMessage!)
              else if (places.isEmpty)
                _buildEmptyPlacesState()
              else
                ...places.map((place) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.stackMd),
                  child: _buildPlaceCard(context, place),
                )),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: AppSpacing.stackMd),
            Text('Could not load your recommendations', style: AppTypography.headlineMd),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(message, style: AppTypography.bodyMd, textAlign: TextAlign.center),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            AppButton(
              text: 'Retry',
              icon: Icons.refresh,
              variant: AppButtonVariant.outline,
              height: 44,
              onPressed: () => context.read<HiddenPlaceProvider>().loadMyRecommendations(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlacesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.place_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.stackMd),
            Text('No recommendations yet', style: AppTypography.headlineMd),
            const SizedBox(height: 4),
            Text('Discover and recommend hidden gems to fellow travelers.', style: AppTypography.bodyMd),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceCard(BuildContext context, RecommendedPlaceModel place) {
    final isUnderVoting = place.status == 'UNDER_VOTING';
    final isReportedClosed = place.status == 'REPORTED_CLOSED';

    final (chipBg, chipFg, chipLabel) = isUnderVoting
        ? (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'Under Voting')
        : isReportedClosed
            ? (AppColors.errorContainer, AppColors.error, 'Removed')
            : (AppColors.successContainer, AppColors.success, 'Verified');

    return Container(
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
                child: Text(place.name, style: AppTypography.headlineMd.copyWith(fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: AppRadii.roundedSm,
                ),
                child: Text(
                  chipLabel,
                  style: AppTypography.labelSm.copyWith(color: chipFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(place.address, style: AppTypography.labelSm, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text('Submitted on ${place.submittedAt.day}/${place.submittedAt.month}/${place.submittedAt.year}', style: AppTypography.labelSm),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Details',
                  icon: Icons.info_outline,
                  variant: AppButtonVariant.outline,
                  height: 40,
                  onPressed: () {
                    AppNavigation.toRecommendedPlaceDetails(
                      context,
                      placeId: place.id,
                      isUnderVoting: isUnderVoting,
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: AppButton(
                  text: 'Withdraw',
                  icon: Icons.delete_outline,
                  variant: AppButtonVariant.destructive,
                  height: 40,
                  onPressed: isUnderVoting
                      ? () {
                          AppNavigation.openWithdrawModal(
                            context,
                            placeId: place.id,
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String count, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                count,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineMd.copyWith(fontSize: 16, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSm,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 32, color: AppColors.outline);
  }
}