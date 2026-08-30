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
import '../recommend_new_place/place_details_screen.dart';
import '../recommend_new_place/recommend_place_screen.dart';
import '../recommend_new_place/recommend_location_screen.dart';
import '../recommend_new_place/recommend_location_preview_screen.dart';
import '../recommend_new_place/recommend_review_screen.dart';
import '../recommend_new_place/recommendation_success_screen.dart';
import '../recommend_new_place/recommend_place_draft.dart';
import '../post_review/status/status_feedback_screen.dart';
import '../post_review/status/loading_state_screen.dart';
import '../../theme/app_theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Runs once per app process: decides whether the very first screen should
// be the entry page (first ever launch), Login (no/expired session), or
// straight into the app (a stored session was successfully restored).
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
      builder: (context, state) => const EntryPageUi(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginUi(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        // ?tab=post → Post Feed tab (index 2); default → Explore (index 0).
        return MainPage(initialTab: tab == 'post' ? 2 : 0);
      },
    ),

    // 2. Profile Domain
    GoRoute(
      path: '/profile/recommended-places',
      builder: (context, state) => const MyRecommendedPlacesScreen(),
    ),

    // 3. Post Domain
    GoRoute(
      path: '/post/create',
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
      builder: (context, state) {
        final postId = state.pathParameters['postId'] ?? 'post-001';
        return PostDetailsScreen(postId: postId);
      },
    ),
    GoRoute(
      path: '/post/edit/:postId',
      builder: (context, state) {
        final postId = state.pathParameters['postId'];
        return EditPostScreen(postId: postId);
      },
    ),
    GoRoute(
      path: '/post/preview',
      builder: (context, state) =>
          PreviewChangesScreen(postId: state.extra as String?),
    ),

    // 4. Place Domain
    GoRoute(
      path: '/places/details/verified',
      builder: (context, state) {
        final placeId = state.uri.queryParameters['placeId'];
        return PlaceDetailsScreen(
          status: PlaceStatus.verified,
          placeId: placeId,
        );
      },
    ),
    GoRoute(
      path: '/places/details/under-voting',
      builder: (context, state) {
        final placeId = state.uri.queryParameters['placeId'];
        return PlaceDetailsScreen(
          status: PlaceStatus.underVoting,
          placeId: placeId,
        );
      },
    ),
    GoRoute(
      path: '/places/recommend',
      builder: (context, state) => RecommendPlaceScreen(
        // Pre-fill the form when returning from "Edit Details" on the Review
        // step (the draft is carried back as navigation `extra`).
        initialDraft: state.extra as RecommendPlaceDraft?,
      ),
    ),
    GoRoute(
      path: '/places/recommend/location',
      builder: (context, state) =>
          RecommendLocationScreen(draft: state.extra as RecommendPlaceDraft),
    ),
    GoRoute(
      path: '/places/recommend/preview',
      builder: (context, state) => RecommendLocationPreviewScreen(
          draft: state.extra as RecommendPlaceDraft),
    ),
    GoRoute(
      path: '/places/recommend/review',
      builder: (context, state) =>
          RecommendReviewScreen(draft: state.extra as RecommendPlaceDraft),
    ),
    GoRoute(
      path: '/places/recommend/success',
      builder: (context, state) => const RecommendationSuccessScreen(),
    ),

    // 5. Transient Status Feedback
    GoRoute(
      path: '/status/loading',
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
      path: '/status/post-updated',
      builder: (context, state) => StatusFeedbackScreen(
        title: 'Update Successful',
        heading: 'Post Updated Successfully!',
        message: 'Your latest changes are now live and published across the platform.',
        icon: Icons.check,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryContainer,
        primaryButtonText: 'Return',
        onPrimaryPressed: () => context.pop(),
      ),
    ),
    GoRoute(
      path: '/post/select-attraction',
      builder: (context, state) => const SelectAttractionScreen(),
    ),
    GoRoute(
      path: '/status/post-deleted',
      builder: (context, state) => StatusFeedbackScreen(
        title: '',
        heading: 'Post deleted',
        message: 'Your post has been successfully deleted.',
        icon: Icons.description_outlined,
        iconColor: AppColors.primary,
        iconBgColor: const Color(0xFFFDECE7),
        primaryButtonText: 'Back to Post Feed',
        onPrimaryPressed: () => context.go('/main?tab=post'),
      ),
    ),
    GoRoute(
      path: '/status/report-submitted',
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