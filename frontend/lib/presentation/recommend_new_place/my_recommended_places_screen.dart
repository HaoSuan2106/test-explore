import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/content_constraint.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';
import '../../models/hidden_place/recommended_place_model.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart';
import '../navigation/app_navigation.dart';
import '../place_details/place_details_ui.dart';

class MyRecommendedPlacesScreen extends StatefulWidget {
  const MyRecommendedPlacesScreen({super.key});

  @override
  State<MyRecommendedPlacesScreen> createState() => _MyRecommendedPlacesScreenState();
}

class _MyRecommendedPlacesScreenState extends State<MyRecommendedPlacesScreen> {
  /// True while a manual/pull refresh triggered from this screen is running.
  /// The provider keeps the loaded list visible during refresh, so this only
  /// drives the thin inline indicator.
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HiddenPlaceProvider>().loadMyRecommendations();
      }
    });
  }

  /// Reloads the place list through the EXISTING canonical loader
  /// (`HiddenPlaceProvider.loadMyRecommendations`). No second loading system,
  /// no duplicate API call — refresh simply awaits the same method the screen
  /// and its Retry / withdraw flows already use.
  ///
  /// Returns the content-aware refresh outcome so pull-to-refresh and the
  /// refresh button can show the correct toast ("Updated successfully" /
  /// "Already up to date" / error) based on a real data comparison — never
  /// on HTTP success alone.
  Future<RecommendationRefreshOutcome> _reloadPlaces() async {
    if (_isRefreshing) {
      return RecommendationRefreshOutcome.unchanged;
    }
    setState(() => _isRefreshing = true);
    try {
      return await context
          .read<HiddenPlaceProvider>()
          .refreshMyRecommendationsWithFeedback();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// Shows the toast matching a finished refresh outcome (spec Part 14 —
  /// short wording, no dialogs). Errors keep the previously loaded list
  /// visible (the provider never clears it on failure).
  void _showRefreshToast(RecommendationRefreshOutcome outcome) {
    if (!mounted) return;
    switch (outcome) {
      case RecommendationRefreshOutcome.changed:
        AppFeedback.show(context, message: 'Updated successfully', isSuccess: true);
      case RecommendationRefreshOutcome.unchanged:
        AppFeedback.show(context, message: 'Already up to date', isSuccess: true);
      case RecommendationRefreshOutcome.error:
        AppFeedback.show(context,
            message: "Couldn't refresh. Please try again.", isSuccess: false);
    }
  }

  Future<void> _onPullToRefresh() async {
    final outcome = await _reloadPlaces();

    if (!mounted) return;

    _showRefreshToast(outcome);
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
                    AppSpacing.containerMargin, AppSpacing.stackSm,
                    AppSpacing.containerMargin, 0),
                child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
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
              // Thin inline indicator for button-triggered refreshes; the
              // loaded list stays fully visible beneath it.
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: AppSpacing.stackMd),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin),
                child: Row(
                  children: [
                    Text('Your Place Submissions',
                        style: AppTypography.headlineMd.copyWith(fontSize: 16)),
                    const Spacer(),
                    // Compact manual refresh control (~36px, matching the
                    // Post Feed compact-control principles).
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _isRefreshing
                          ? null
                          : () async =>
                              _showRefreshToast(await _reloadPlaces()),
                      icon: const Icon(Icons.refresh, size: 20),
                      color: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
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

    // G-01 fix: pass the FULL photo list to Place Details, not just photo 1.
    //
    // photosJson on the list model is a List<String> of public image URLs (the
    // backend serializes RecommendPlace.PhotosJson with
    // System.Text.Json.JsonSerializer.Serialize — see
    // HiddenPlaceContributionService.SubmitAsync). PlaceData.photosJson is the
    // raw JSON string field carried by the working Explore Map path
    // (hidden_place_discovery_ui.dart _toPlaceData), and Place Details' photo
    // sources read it with the SAME jsonDecode + is List contract (see
    // place_details_ui.dart _getPlacePhotoUrls / _parseOpeningHoursJson).
    // jsonEncode here reproduces that established representation exactly — no
    // new format is invented. photos.first stays on imageUrl so the collage's
    // primary tile keeps its URL even when _getPlacePhotoUrls is not reached,
    // and dedupe in _getPlacePhotoUrls prevents double-counting photo 1.
    final photosJson = photos.isNotEmpty ? jsonEncode(photos) : null;

    // Route the recommendation's Place Details screen through GoRouter +
    // typed AppNavigation (P6.1). The list model's id IS the community
    // submission id (UUID) — the recommend_place_id the Place Details UI keys
    // the Community / Verification Status UI on (isCommunity is a derived
    // getter on PlaceData, never force-set).
    AppNavigation.toPlaceDetails(
      context,
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
        photosJson: photosJson,
        regularOpeningHoursJson: null,
      ),
      reviewTargetType: PlaceReviewTargetType.system,
    );
  }

  /// OWNER WITHDRAWAL — confirms the owner wants to withdraw their own
  /// recommendation, calls the API, and refreshes the list.
  Future<void> _confirmWithdraw(
      BuildContext context, String placeId, String placeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Recommendation'),
        content: Text(
          'Are you sure you want to withdraw "$placeName"? '
          'It will no longer be visible to others.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw', style: TextStyle(color: Color(0xFFFF6242))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final provider = context.read<HiddenPlaceProvider>();
    final success = await provider.withdrawRecommendation(placeId);

    if (!context.mounted) return;

    if (success) {
      // Refresh the entire list so the withdrawn status is visible.
      await provider.loadMyRecommendations();
      if (!context.mounted) return;
      AppFeedback.show(context, message: 'Your recommendation has been withdrawn.', isSuccess: true);
    } else if (context.mounted) {
      AppFeedback.show(
        context,
        message: provider.errorMessage ?? 'Failed to withdraw recommendation.',
        isSuccess: false,
      );
    }
  }

  /// Lazy-rendered list of the user's recommendation cards (loading / error /
  /// empty states share the same scroll area so the stats header stays put).
  /// Every settled state (loaded / empty / error) is wrapped in a
  /// [RefreshIndicator] so pulling down always offers a reload through the
  /// existing canonical loader.
  Widget _buildPlacesList(HiddenPlaceProvider placeProvider) {
    final places = placeProvider.userRecommendations;
    if (placeProvider.isLoading && places.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (placeProvider.errorMessage != null && places.isEmpty) {
      // `return` is required — without it this branch is dead code and a
      // failed first load falls through to the empty state, hiding the
      // error message + Retry from the user.
      return RefreshIndicator(
        onRefresh: _onPullToRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_buildLoadErrorState(placeProvider.errorMessage!)],
        ),
      );
    }
    if (places.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async =>
            _showRefreshToast(await _reloadPlaces()),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_buildEmptyPlacesState()],
        ),
      );
    }
    // Loaded state: the SAME wrapper as the empty/error states so EVERY
    // pull-to-refresh path shows the outcome toast (changed / unchanged /
    // error). _reloadPlaces alone would refresh silently — no feedback.
    return RefreshIndicator(
      onRefresh: _onPullToRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
    // REAL data of the tapped recommendation (Edit keeps its own onPressed).
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
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Edit',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.outline,
                  height: 36,
                  onPressed: isUnderVoting
                      ? () {
                          AppNavigation.toEditRecommendation(
                              context, place: place);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  text: 'Withdraw',
                  icon: Icons.remove_circle_outline,
                  variant: AppButtonVariant.outline,
                  height: 36,
                  // Same gate as Edit: only UNDER_VOTING submissions may be
                  // withdrawn from the list — a VERIFIED place is locked.
                  onPressed: isUnderVoting && !place.isWithdrawn
                      ? () => _confirmWithdraw(context, place.id, place.name)
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