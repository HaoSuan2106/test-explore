import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../post_review/status/loading_state_screen.dart';
import '../recommend_new_place/recommend_place_draft.dart';
import '../recommend_new_place/recommendation_success_screen.dart';
import '../place_details/community_verification/community_verification_ui.dart';
import '../place_details/place_detail_args.dart';
import '../place_details/create_review/create_review_args.dart';
import '../place_details/create_review/create_review_ui.dart' show ReviewPlaceType;
import '../route_navigation/route_navigation_args.dart';
import '../place_details/report_review/report_review_args.dart';
import '../../models/hidden_place/recommended_place_model.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart' show PlaceData;
import '../place_details/place_details_ui.dart' show PlaceReviewTargetType;

class AppNavigation {
  /// Navigate to Main Shell
  static void toMain(BuildContext context) {
    context.go('/main');
  }

  /// Navigate to the Login screen (used after logout / from entry).
  ///
  /// Must go through the router: a raw Navigator.push here would leave
  /// GoRouter's internal state pointing at the previous location while the
  /// visible screen changes, so the next router navigation would be issued
  /// against a stale location.
  static void toLogin(BuildContext context) {
    context.go('/login');
  }

  /// Open Post Details
  static void toPostDetails(
      BuildContext context, {
        required String postId,
      }) {
    context.push('/post/details/$postId');
  }

  /// NEW: Open Select Attraction pre-create flow
  static void toSelectAttraction(BuildContext context) {
    context.push('/post/select-attraction');
  }

  /// Open Create Post with optional pre-selected attraction details
  static void toCreatePost(
      BuildContext context, {
        String? attractionName,
        String? attractionLocation,
        String? attractionId,
      }) {
    final uri = Uri(
      path: '/post/create',
      queryParameters: {
        'name': ?attractionName,
        'location': ?attractionLocation,
        'placeId': ?attractionId,
      },
    );
    context.push(uri.toString());
  }

  /// Open Edit Post and await a typed result from the editor.
  ///
  /// Returns `PostEditResult.updated` when the editor saved the post, or
  /// `null` when the user cancelled / nothing changed. The caller is
  /// responsible for `if (!mounted) return` after awaiting.
  static Future<T?> toEditPost<T>(
      BuildContext context, {
        required String postId,
      }) {
    return context.push<T?>('/post/edit/$postId');
  }

  /// Open Preview Changes
  static void toPreviewChanges(BuildContext context, {String? postId}) {
    context.push('/post/preview', extra: postId);
  }

  /// Open My Recommended Places under Profile
  static void toMyRecommendedPlaces(BuildContext context) {
    context.push('/profile/recommended-places');
  }

  /// Open Recommend New Place Form (STEP 1 — Place Details)
  static void toRecommendPlace(BuildContext context) {
    context.push('/places/recommend');
  }

  /// Open the wizard pre-filled for editing an existing recommendation.
  /// The draft carries the existing data and the [editingSubmissionId] so the
  /// review screen branches to PUT instead of POST.
  static void toEditRecommendation(
      BuildContext context, {
        required RecommendedPlaceModel place,
      }) {
    // The existing photos (public URLs already stored in photosJson) are
    // carried into the wizard verbatim. They are NEVER re-uploaded or
    // re-downloaded; they only disappear if the user explicitly removes them.
    context.push('/places/recommend', extra: RecommendPlaceDraft(
      name: place.name,
      primaryType: place.primaryType,
      description: place.description,
      latitude: place.latitude,
      longitude: place.longitude,
      priceLevel: place.priceLevel,
      photoPaths: place.photosJson ?? const [],
      editingSubmissionId: place.id,
    ));
  }

  /// Open STEP 2 — Direct Map Location (fixed center pin, drag map)
  static void toRecommendLocation(
      BuildContext context, {
        required RecommendPlaceDraft draft,
      }) {
    context.push('/places/recommend/location', extra: draft);
  }

  /// Open STEP 3 — Location Preview
  static void toRecommendLocationPreview(
      BuildContext context, {
        required RecommendPlaceDraft draft,
      }) {
    context.push('/places/recommend/preview', extra: draft);
  }

  /// Open STEP 4 — Review
  static void toRecommendReview(
      BuildContext context, {
        required RecommendPlaceDraft draft,
      }) {
    context.push('/places/recommend/review', extra: draft);
  }

  /// Open Recommendation Success — a completed flow terminal screen.
  ///
  /// Pops the wizard stack (Step 1 → Step 2 → Step 3 → Review) back to the
  /// process parent (My Recommended Places), then pushes the Success terminal
  /// on top. System back / edge-swipe from Success therefore returns to My
  /// Recommended Places — never a wizard step, Profile, or app exit.
  ///
  /// Contrast with the original `go()` design, which replaced the entire stack
  /// with a single Success route and made system back exit the app. The
  /// requirement (R1/R2/G) explicitly mandates back → My Recommended Places,
  /// so the requirement supersedes the earlier design intent.
  ///
  /// [submissionId] is the recommendation's identifier returned by the submit /
  /// update API — carried as route `extra` so the Success screen can offer a
  /// direct "View Recommendation" link to its Details page.
  ///
  /// [isUpdate] distinguishes an edited recommendation ("updated successfully")
  /// from a brand-new submission ("submitted"), so the terminal copy and the
  /// return flow match what actually happened.
  ///
  /// [verificationCount] is the authoritative, persisted verification count
  /// returned by the backend for this recommendation (R-07 Option A). It drives
  /// the Success copy ("by N explorers") — never a hardcoded 5.
  static void toRecommendationSuccess(
      BuildContext context, {
        String? submissionId,
        bool isUpdate = false,
        int verificationCount = 0,
      }) {
    final navigator = Navigator.of(context);
    // Pop the wizard stack (Step 1 → Review) back to the process parent
    // (My Recommended Places), keeping the parent on the stack so that system
    // back / edge-swipe from Success returns there.
    navigator.popUntil((route) =>
        route.settings.name == 'profile-recommended-places' || route.isFirst);
    context.push('/places/recommend/success',
        extra: RecommendationSuccessArgs(
          submissionId: submissionId,
          isUpdate: isUpdate,
          verificationCount: verificationCount,
        ));
  }

  /// Open the Report Review screen.
  static void toReportReview(
    BuildContext context, {
    required int reviewId,
  }) {
    context.push(
      '/place/review-report',
      extra: ReportReviewArgs(reviewId: reviewId),
    );
  }

  /// Open the Route Navigation (Direction) screen.
  static void toDirection(
    BuildContext context, {
    required String destinationName,
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
    required String? destinationCategory,
    String? destinationPlaceId,
  }) {
    context.push(
      '/place/direction',
      extra: RouteNavigationArgs(
        destinationName: destinationName,
        destinationAddress: destinationAddress,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        destinationCategory: destinationCategory,
        destinationPlaceId: destinationPlaceId,
      ),
    );
  }

  /// Open the Create Review screen (create or edit).
  ///
  /// Returns true when the review was persisted, null on cancel.
  static Future<bool?> toCreateReview(
    BuildContext context, {
    int initialRating = 0,
    String initialReviewText = '',
    String? placeId,
    ReviewPlaceType placeType = ReviewPlaceType.google,
    String? placeName,
    bool isEdit = false,
    int? reviewId,
    List<dynamic> initialPhotos = const [],
  }) {
    return context.push<bool?>(
      '/place/review',
      extra: CreateReviewArgs(
        initialRating: initialRating,
        initialReviewText: initialReviewText,
        placeId: placeId,
        placeType: placeType,
        placeName: placeName,
        isEdit: isEdit,
        reviewId: reviewId,
        initialPhotos: initialPhotos,
      ),
    );
  }

  /// Open the Place Details screen for a community recommendation.
  ///
  /// The caller must supply a fully-prepared [PlaceData] (loaded via
  /// [HiddenPlaceProvider.loadRecommendationDetails]). The route builder
  /// reconstructs the [PlaceDetailUI] from this payload without re-fetching.
  static void toPlaceDetails(
    BuildContext context, {
    required PlaceData place,
    PlaceReviewTargetType reviewTargetType = PlaceReviewTargetType.google,
  }) {
    context.push(
      '/place/details',
      extra: PlaceDetailArgs(
        place: place,
        reviewTargetType: reviewTargetType,
      ),
    );
  }

  /// Open the Community Verification screen for a RECOMMENDED PLACE.
  ///
  /// The [placeId] MUST be the recommended-place SUBMISSION id (UUID), never a
  /// Google place_id. Returns the user's final vote ([CommunityUserVote]) so
  /// the caller can sync its provider-backed state after the mutation.
  static Future<CommunityUserVote?> toCommunityVerification(
      BuildContext context, {
        required String placeId,
        required CommunityPlaceStatus placeStatus,
        required CommunityUserVote userVote,
        required String placeName,
        required String recommendedBy,
        required bool hasReported,
        required bool isReportedClosed,
      }) {
    return context.push<CommunityUserVote?>(
      '/place/community-verification',
      extra: CommunityVerificationArgs(
        placeId: placeId,
        placeStatus: placeStatus,
        userVote: userVote,
        placeName: placeName,
        recommendedBy: recommendedBy,
        hasReported: hasReported,
        isReportedClosed: isReportedClosed,
      ),
    );
  }

  /// Open the shared transient loading screen for an operation
  static void toStatusLoading(
      BuildContext context, {
        String? title,
        String? heading,
        String? message,
      }) {
    context.push(
      '/status/loading',
      extra: LoadingStateArgs(title: title, heading: heading, message: message),
    );
  }

  /// Open Report Submitted Thank You Screen
  static void toReportSubmittedSuccess(BuildContext context) {
    context.push('/status/report-submitted');
  }

  /// Edit Location from the Review screen — replaces the review with STEP 2.
  static void toEditRecommendLocation(
      BuildContext context, {
        required RecommendPlaceDraft draft,
      }) {
    context.pushReplacement('/places/recommend/location', extra: draft);
  }

  /// Edit Details from the Review screen — replaces the review with STEP 1
  /// so the stack stays clean (no stale review behind the wizard).
  static void toEditRecommendDetails(
      BuildContext context, {
        required RecommendPlaceDraft draft,
      }) {
    context.pushReplacement('/places/recommend', extra: draft);
  }

}