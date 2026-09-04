import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/content_constraint.dart';
import '../../../widgets/app_feedback.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart'
    hide AppColors;
import '../navigation/app_navigation.dart';
import '../place_details/place_details_ui.dart';

/// Arguments carried to the Recommendation Success terminal via go_router
/// `extra`. Distinguishes a brand-new submission from an update so the copy
/// and the return flow match what actually completed.
class RecommendationSuccessArgs {
  final String? submissionId;
  final bool isUpdate;

  /// The authoritative, persisted verification count returned by the backend
  /// for this recommendation (RecommendedPlaceDetailsDto.VerificationCount).
  /// Drives the R-07 success copy ("by N explorers") — never a hardcoded 5.
  final int? verificationCount;

  const RecommendationSuccessArgs({
    this.submissionId,
    this.isUpdate = false,
    this.verificationCount,
  });
}

/// Final screen of the Recommend Place wizard — Submission/Update Success.
///
/// Reached after STEP 4 submit (create) or edit submit (update) succeeds.
/// Exits:
///   - "View Recommendation" → Place Details (place_details_ui.dart)
///   - "View My Recommendations" → My Recommended Places
///   - "Back to Home" → Post Feed (Main shell)
class RecommendationSuccessScreen extends StatelessWidget {
  /// The recommendation's identifier (returned by the submit/update API).
  /// When present it enables the direct "View Recommendation" exit to the
  /// Place Details page.
  final String? submissionId;

  /// True when this terminal was reached by UPDATING an existing
  /// recommendation rather than submitting a new one.
  final bool isUpdate;

  /// The authoritative, persisted verification count (R-07 Option A).
  /// Comes from the backend's RecommendedPlaceDetailsDto.VerificationCount
  /// and flows through the provider — never a hardcoded 5.
  final int verificationCount;

  const RecommendationSuccessScreen({
    super.key,
    this.submissionId,
    this.isUpdate = false,
    this.verificationCount = 0,
  });

  /// Loads the freshly submitted recommendation and opens its details in the
  /// shared [PlaceDetailUI]. Shows an error snackbar when the place cannot be
  /// loaded and falls back to "My Recommended Places" (no silent failure).
  Future<void> _openRecommendation(BuildContext context, String placeId) async {
    final provider = context.read<HiddenPlaceProvider>();
    final place = await provider.loadRecommendationDetails(placeId);

    if (!context.mounted) return;

    if (place == null) {
      if (!context.mounted) return;
      AppFeedback.show(context,
        message: 'Could not load the recommendation details. '
            'Please try again from My Recommended Places.',
        isSuccess: false,
      );
      _backToMyRecommendedPlaces(context);
      return;
    }

    final photos = place.photosJson ?? const <String>[];

    // Route the recommendation's Place Details screen through GoRouter +
    // typed AppNavigation (P6.1). place.id is the community submission id
    // (UUID) — the actual recommend_place_id the Place Details UI keys the
    // Community / Verification Status UI on (isCommunity is a derived getter
    // on PlaceData, never force-set).
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
        photosJson: null,
        regularOpeningHoursJson: null,
      ),
      reviewTargetType: PlaceReviewTargetType.system,
    );
  }

  /// Returns to My Recommended Places (the process parent). The Success
  /// terminal is pushed ON TOP of My Recommended Places by
  /// [AppNavigation.toRecommendationSuccess], so returning means popping back
  /// to it — never pushing a duplicate instance. Falls back to a fresh
  /// navigation when the parent is not on the stack (direct deep-link entry).
  void _backToMyRecommendedPlaces(BuildContext context) {
    final navigator = Navigator.of(context);
    var reachedParent = false;
    navigator.popUntil((route) {
      if (route.settings.name == 'profile-recommended-places') {
        reachedParent = true;
        return true;
      }
      return route.isFirst;
    });
    if (!reachedParent) {
      AppNavigation.toMyRecommendedPlaces(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Recommendation Submitted',
        showBack: false,
      ),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.successContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                Text(
                  isUpdate
                      ? 'Recommendation Updated!'
                      : 'Recommendation Submitted!',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineLg,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  // R-07 Option A: communicate the number of explorers who
                  // verified this recommendation. The count is the persisted
                  // backend value (RecommendedPlaceDetailsDto.VerificationCount)
                  // carried through the provider — never a hardcoded figure.
                  'Your recommendation has been verified\n'
                  'by $verificationCount explorers',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackLg * 2),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'View Recommendation',
                    icon: Icons.visibility_outlined,
                    onPressed:
                        (submissionId != null && submissionId!.isNotEmpty)
                        ? () => _openRecommendation(context, submissionId!)
                        : () => _backToMyRecommendedPlaces(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'View My Recommendations',
                    icon: Icons.place_outlined,
                    variant: AppButtonVariant.outline,
                    onPressed: () => _backToMyRecommendedPlaces(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Back to Home',
                    icon: Icons.home_outlined,
                    variant: AppButtonVariant.outline,
                    onPressed: () => AppNavigation.toMain(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
