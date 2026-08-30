import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../api_communication/http_client/http_client.dart';

class ReviewProvider extends ChangeNotifier {
  ReviewProvider({
    required HttpClient httpClient,
  }) : _httpClient = httpClient;

  final HttpClient _httpClient;

  Future<dynamic> createReview({
    String? googlePlaceId,
    String? recommendPlaceId,
    required int rating,
    required String comment,
  }) async {
    return await _httpClient.createHiddenPlaceReview(
      googlePlaceId: googlePlaceId,
      recommendPlaceId: recommendPlaceId,
      rating: rating,
      comment: comment,
    );
  }

  Future<List<dynamic>> uploadReviewPhotos({
    required int reviewId,
    required List<File> files,
  }) async {
    return await _httpClient.uploadHiddenPlaceReviewPhotos(
      reviewId: reviewId,
      files: files,
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

  Future<void> deleteReviewPhoto({
    required int reviewId,
    required int reviewPhotoId,
  }) async {
    await _httpClient.deleteHiddenPlaceReviewPhoto(
      reviewId: reviewId,
      reviewPhotoId: reviewPhotoId,
    );
  }

  Future<void> reportReview({
    required int reviewId,
    required String reason,
  }) async {
    await _httpClient.reportHiddenPlaceReview(
      reviewId: reviewId,
      reason: reason,
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