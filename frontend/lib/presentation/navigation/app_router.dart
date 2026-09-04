import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Presentation imports
import '../authentication/login/login_ui.dart';
import '../post_review/post/select_attraction_screen.dart';
import 'entry_page_ui.dart';
import 'main_page.dart';
import '../../providers/auth_profile/auth_provider.dart';
import '../../providers/auth_profile/profile_provider.dart';
import '../../utilities/onboarding_preferences.dart';

// Feature screens
import '../view_my_post_activity/post_details_screen.dart';
import '../post_review/post/edit_post_screen.dart';
import '../post_review/post/preview_changes_screen.dart';
import '../recommend_new_place/my_recommended_places_screen.dart';
import '../recommend_new_place/recommend_place_screen.dart';
import '../recommend_new_place/recommend_location_screen.dart';
import '../recommend_new_place/recommend_location_preview_screen.dart';
import '../recommend_new_place/recommend_review_screen.dart';
import '../recommend_new_place/recommendation_success_screen.dart';
import '../recommend_new_place/recommend_place_draft.dart';
import '../post_review/status/status_feedback_screen.dart';
import '../place_details/community_verification/community_verification_ui.dart';
import '../place_details/place_detail_args.dart';
import '../place_details/place_details_ui.dart';
import '../place_details/create_review/create_review_args.dart';
import '../route_navigation/navigation_screen.dart';
import '../place_details/report_review/report_review_args.dart';
import '../place_details/report_review/report_review_ui.dart';
import '../route_navigation/route_navigation_args.dart';
import '../place_details/create_review/create_review_ui.dart';
import '../post_review/status/loading_state_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Runs once per app process: decides whether the very first screen should
// be the entry page (first ever launch), Login (no/expired session), or
// straight into the app (a stored session was successfully restored).
//
// NOTE: This flag is set SYNCHRONOUSLY before the async startup chain
// (hasSeenEntryPage → tryAutoLogin → loadCachedAvatar → loadProfile) runs.
// Empirical testing confirmed this is SAFE in GoRouter 17.5.0: the early
// flag ensures any concurrent navigation during the pending startup window
// gets a null redirect (skip the startup decision) and proceeds immediately,
// rather than racing the still-resolving startup Future. See
// test/first_launch_navigation_test.dart for the deterministic test.
bool _hasCheckedStartupSession = false;

/// Declarative router configuration
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/main',

  redirect: (BuildContext context, GoRouterState state) async {
    if (_hasCheckedStartupSession) return null;
    _hasCheckedStartupSession = true;

    final hasSeenEntry = await const OnboardingPreferences().hasSeenEntryPage();
    if (!hasSeenEntry) return '/entry';
    if (!context.mounted) return null;

    final restored = await context.read<AuthProvider>().tryAutoLogin();
    if (!restored) return '/login';
    if (!context.mounted) return null;

    final profileProvider = context.read<ProfileProvider>();
    // Put the cached avatar on screen first — it needs no network, so it is
    // still there when the profile request below fails offline.
    await profileProvider.loadCachedAvatar();
    await profileProvider.loadProfile();
    return '/main';
  },

  routes: [
    // 1. Core Shell & Auth
    GoRoute(
      path: '/entry',
      name: 'entry',
      builder: (context, state) => const EntryPageUi(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginUi(),
    ),
    GoRoute(
      path: '/main',
      name: 'main',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        // ?tab=post → Post Feed tab (index 2); default → Explore (index 0).
        return MainPage(initialTab: tab == 'post' ? 2 : 0);
      },
    ),

    // 2. Profile Domain
    GoRoute(
      path: '/profile/recommended-places',
      name: 'profile-recommended-places',
      builder: (context, state) => const MyRecommendedPlacesScreen(),
    ),

    // 3. Post Domain
    GoRoute(
      path: '/post/create',
      name: 'post-create',
      builder: (context, state) {
        final location = state.uri.queryParameters['location'];
        final placeId = state.uri.queryParameters['placeId'];
        return EditPostScreen(
          postId: null,
          initialTaggedLocation: location,
          initialTaggedPlaceId: placeId,
        );
      },
    ),
    GoRoute(
      path: '/post/details/:postId',
      name: 'post-details',
      builder: (context, state) {
        final postId = state.pathParameters['postId'] ?? 'post-001';
        return PostDetailsScreen(postId: postId);
      },
    ),
    GoRoute(
      path: '/post/edit/:postId',
      name: 'post-edit',
      builder: (context, state) {
        final postId = state.pathParameters['postId'];
        return EditPostScreen(postId: postId);
      },
    ),
    GoRoute(
      path: '/post/preview',
      name: 'post-preview',
      builder: (context, state) =>
          PreviewChangesScreen(postId: state.extra as String?),
    ),

    // 4. Place Domain
    GoRoute(
      path: '/places/recommend',
      name: 'places-recommend',
      builder: (context, state) => RecommendPlaceScreen(
        // Pre-fill the form when returning from "Edit Details" on the Review
        // step (the draft is carried back as navigation `extra`).
        initialDraft: state.extra as RecommendPlaceDraft?,
      ),
    ),
    GoRoute(
      path: '/places/recommend/location',
      name: 'places-recommend-location',
      builder: (context, state) =>
          RecommendLocationScreen(draft: state.extra as RecommendPlaceDraft),
    ),
    GoRoute(
      path: '/places/recommend/preview',
      name: 'places-recommend-preview',
      builder: (context, state) => RecommendLocationPreviewScreen(
          draft: state.extra as RecommendPlaceDraft),
    ),
    GoRoute(
      path: '/places/recommend/review',
      name: 'places-recommend-review',
      builder: (context, state) =>
          RecommendReviewScreen(draft: state.extra as RecommendPlaceDraft),
    ),
    GoRoute(
      path: '/place/details',
      name: 'place-details',
      builder: (context, state) {
        final args = state.extra as PlaceDetailArgs;
        return Scaffold(
          backgroundColor: Colors.white,
          body: PlaceDetailUI(
            place: args.place,
            reviewTargetType: args.reviewTargetType,
          ),
        );
      },
    ),
    GoRoute(
      path: '/place/review',
      name: 'place-review',
      builder: (context, state) {
        final args = state.extra as CreateReviewArgs;
        return CreateReviewUI(
          initialRating: args.initialRating,
          initialReviewText: args.initialReviewText,
          placeId: args.placeId,
          placeType: args.placeType,
          placeName: args.placeName,
          isEdit: args.isEdit,
          reviewId: args.reviewId,
          initialPhotos: args.initialPhotos,
        );
      },
    ),
    GoRoute(
      path: '/place/direction',
      name: 'place-direction',
      builder: (context, state) {
        final args = state.extra as RouteNavigationArgs;
        return RouteNavigationScreen(
          destinationName: args.destinationName,
          destinationAddress: args.destinationAddress,
          destinationLat: args.destinationLat,
          destinationLng: args.destinationLng,
          destinationCategory: args.destinationCategory,
          destinationPlaceId: args.destinationPlaceId,
        );
      },
    ),
    GoRoute(
      path: '/place/review-report',
      name: 'place-review-report',
      builder: (context, state) {
        final args = state.extra as ReportReviewArgs;
        return ReportReviewUI(reviewId: args.reviewId);
      },
    ),
    GoRoute(
      path: '/place/community-verification',
      name: 'community-verification',
      builder: (context, state) {
        final args = state.extra as CommunityVerificationArgs;
        return CommunityVerificationUI(
          placeId: args.placeId,
          placeStatus: args.placeStatus,
          userVote: args.userVote,
          placeName: args.placeName,
          recommendedBy: args.recommendedBy,
          hasReported: args.hasReported,
          isReportedClosed: args.isReportedClosed,
        );
      },
    ),
    GoRoute(
      path: '/places/recommend/success',
      name: 'places-recommend-success',
      builder: (context, state) {
        final args = state.extra is RecommendationSuccessArgs
            ? (state.extra as RecommendationSuccessArgs)
            : null;
        return RecommendationSuccessScreen(
          submissionId: args?.submissionId,
          isUpdate: args?.isUpdate ?? false,
          verificationCount: args?.verificationCount ?? 0,
        );
      },
    ),

    // 5. Transient Status Feedback
    GoRoute(
      path: '/status/loading',
      name: 'status-loading',
      builder: (context, state) {
        final args = state.extra is LoadingStateArgs
            ? (state.extra as LoadingStateArgs)
            : null;
        return LoadingStateScreen(
          title: args?.title ?? 'Please Wait',
          heading: args?.heading ?? 'Removing...',
          message: args?.message ??
              'We are safely removing the selected item. Please wait a moment.',
        );
      },
    ),
    GoRoute(
      path: '/post/select-attraction',
      name: 'post-select-attraction',
      builder: (context, state) => const SelectAttractionScreen(),
    ),
    GoRoute(
      path: '/status/report-submitted',
      name: 'status-report-submitted',
      builder: (context, state) => StatusFeedbackScreen(
        title: '',
        heading: 'Thank you!',
        message: 'Your report has been submitted.',
        icon: Icons.flag_rounded,
        iconColor: const Color(0xFF5C6BC0),
        iconBgColor: const Color(0xFFE8EAF6),
        primaryButtonText: 'Back to Post Feed',
        onPrimaryPressed: () => context.go('/main?tab=post'),
      ),
    ),
  ],
);