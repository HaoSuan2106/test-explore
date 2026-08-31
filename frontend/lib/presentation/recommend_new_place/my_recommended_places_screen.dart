import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/content_constraint.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';
import '../../models/hidden_place/recommended_place_model.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart'
    hide AppColors;
import '../navigation/app_navigation.dart';
import '../place_details/place_details_ui.dart';

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats header (always visible, not in the scrollable list).
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.containerMargin, AppSpacing.containerMargin,
                    AppSpacing.containerMargin, 0),
                child: Container(
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
              ),
              const SizedBox(height: AppSpacing.stackLg),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin),
                child: Text('Your Place Submissions',
                    style: AppTypography.headlineMd.copyWith(fontSize: 16)),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              // Lazy list of place cards.
              Expanded(
                child: _buildPlacesList(placeProvider),
              ),
            ],
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
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.containerMargin,
            vertical: 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 56,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                'No recommendations yet',
                style: AppTypography.headlineMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Discover and recommend places to fellow travelers.',
                style: AppTypography.bodyMd,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// Opens the shared [PlaceDetailUI] for the selected recommendation.
  ///
  /// Refreshes the place's details first (list summaries omit lat/lng) and
  /// maps the real model into the existing [PlaceData]. No-op when the place
  /// cannot be loaded — never fabricates placeholder data.
  Future<void> _openPlaceDetails(BuildContext context, String placeId) async {
    final provider = context.read<HiddenPlaceProvider>();
    await provider.loadRecommendationDetails(placeId);

    if (!context.mounted) return;

    final place = provider.getPlaceById(placeId);
    if (place == null) return;

    final photos = place.photosJson ?? const <String>[];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          body: PlaceDetailUI(
            place: PlaceData(
              placeId: place.id,
              title: place.name,
              category: place.primaryType,
              primaryType: place.primaryType,
              imageUrl: photos.isNotEmpty ? photos.first : '',
              icon: Icons.place_outlined,
              position: LatLng(place.latitude ?? 0, place.longitude ?? 0),
              rating: 0,
              ratingCount: 0,
              priceLevel: place.priceLevel,
              businessStatus: place.businessStatus ?? 'UNKNOWN',
              // The list model's id IS the community submission id (UUID).
              // It is the actual recommend_place_id the Place Details UI keys
              // the Community / Verification Status UI on (isCommunity is a
              // derived getter on PlaceData, never force-set).
              recommendPlaceId: place.id,
              isVerified: place.isVerified,
              recommendedBy: place.submitterName,
              isReportedByCurrentUser: place.isReportedByCurrentUser,
              isVerifiedByCurrentUser: place.isVerifiedByCurrentUser,
              isReportedClosed: place.status == 'REPORTED_CLOSED',
              address: null,
              phoneNumber: null,
              websiteUri: null,
              googleMapsUri: null,
              photosJson: null,
              regularOpeningHoursJson: null,
            ),
            reviewTargetType: PlaceReviewTargetType.system,
          ),
        ),
      ),
    );
  }

  /// Lazy-rendered list of the user's recommendation cards (loading / error /
  /// empty states share the same scroll area so the stats header stays put).
  Widget _buildPlacesList(HiddenPlaceProvider placeProvider) {
    final places = placeProvider.userRecommendations;
    if (placeProvider.isLoading && places.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (placeProvider.errorMessage != null && places.isEmpty) {
      return _buildLoadErrorState(placeProvider.errorMessage!);
    }
    if (places.isEmpty) {
      return _buildEmptyPlacesState();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        0,
        AppSpacing.containerMargin,
        AppSpacing.stackLg,
      ),
      itemCount: places.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.stackMd),
        child: _buildPlaceCard(context, places[i]),
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

    // The whole card frame is tappable → the shared PlaceDetailUI with the
    // REAL data of the tapped recommendation (Edit / Withdraw remain as their
    // own buttons and keep their individual onPressed handlers).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlaceDetails(context, place.id),
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
                child: Text(
                  (place.latitude != null && place.longitude != null)
                      ? '${place.latitude!.toStringAsFixed(5)}, ${place.longitude!.toStringAsFixed(5)}'
                      : 'No location',
                  style: AppTypography.labelSm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            'Submitted on ${place.submittedAt.toLocal().day}/${place.submittedAt.toLocal().month}/${place.submittedAt.toLocal().year}',
            style: AppTypography.labelSm,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Edit',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.outline,
                  height: 40,
                  onPressed: isUnderVoting
                      ? () {
                          AppNavigation.toEditRecommendation(
                              context, place: place);
                        }
                      : null,
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