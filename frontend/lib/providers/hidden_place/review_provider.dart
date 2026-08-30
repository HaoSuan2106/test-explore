import 'package:flutter/foundation.dart';

import '../../../api_communication/http_client/http_client.dart';

class ReviewProvider extends ChangeNotifier {
  ReviewProvider({
    required HttpClient httpClient,
  }) : _httpClient = httpClient;

  final HttpClient _httpClient;

  Future<void> createReview({
    String? googlePlaceId,
    String? recommendPlaceId,
    required int rating,
    required String comment,
  }) async {
    await _httpClient.createHiddenPlaceReview(
      googlePlaceId: googlePlaceId,
      recommendPlaceId: recommendPlaceId,
      rating: rating,
      comment: comment,
    );
  }

  Future<dynamic> getMyReview({
    String? googlePlaceId,
    String? recommendPlaceId,
  }) async {
    if (googlePlaceId != null) {
      return await _httpClient.getMyGooglePlaceReview(
        googlePlaceId,
      );
    }

    if (recommendPlaceId != null) {
      return await _httpClient.getMyRecommendPlaceReview(
        recommendPlaceId,
      );
    }

    return null;
  }

  Future<void> updateReview({
    required int reviewId,
    required int rating,
    required String comment,
  }) async {
    await _httpClient.updateHiddenPlaceReview(
      reviewId: reviewId,
      rating: rating,
      comment: comment,
    );
  }

  Future<void> deleteReview({
    required int reviewId,
  }) async {
    await _httpClient.deleteHiddenPlaceReview(
      reviewId: reviewId,
    );
  }

  Future<List<dynamic>> getReviews({
    String? googlePlaceId,
    String? recommendPlaceId,
  }) async {
    if (googlePlaceId != null) {
      return await _httpClient.getGooglePlaceReviews(
        googlePlaceId,
      );
    }

    if (recommendPlaceId != null) {
      return await _httpClient.getRecommendPlaceReviews(
        recommendPlaceId,
      );
    }

    return [];
  }
}