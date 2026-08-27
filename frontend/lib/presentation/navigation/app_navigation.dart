import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../post_review/status/loading_state_screen.dart';
import '../recommend_new_place/modals/withdraw_recommendation_modal.dart';
import '../recommend_new_place/recommend_place_draft.dart';

class AppNavigation {
  /// Navigate to Main Shell
  static void toMain(BuildContext context) {
    context.go('/main');
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

  /// Open Edit Post
  static void toEditPost(
      BuildContext context, {
        required String postId,
      }) {
    context.push('/post/edit/$postId');
  }

  /// Open Preview Changes
  static void toPreviewChanges(BuildContext context, {String? postId}) {
    context.push('/post/preview', extra: postId);
  }

  /// Open My Recommended Places under Profile
  static void toMyRecommendedPlaces(BuildContext context) {
    context.push('/profile/recommended-places');
  }

  /// Open Recommended Place Details
  static void toRecommendedPlaceDetails(
      BuildContext context, {
        required String placeId,
        bool isUnderVoting = true,
      }) {
    final status = isUnderVoting ? 'under-voting' : 'verified';
    context.push('/places/details/$status?placeId=$placeId');
  }

  /// Open Recommend New Place Form (STEP 1 — Place Details)
  static void toRecommendPlace(BuildContext context) {
    context.push('/places/recommend');
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

  /// Open Recommendation Success (replaces the review screen in the stack)
  static void toRecommendationSuccess(BuildContext context) {
    context.pushReplacement('/places/recommend/success');
  }

  /// Open In-Situ Withdraw Recommendation Confirmation Sheet
  static void openWithdrawModal(BuildContext context, {String? placeId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WithdrawRecommendationModal(placeId: placeId ?? ''),
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

  /// Open Post Deleted Success Screen (replaces the loading screen)
  static void toPostDeletedSuccess(BuildContext context) {
    context.pushReplacement('/status/post-deleted');
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