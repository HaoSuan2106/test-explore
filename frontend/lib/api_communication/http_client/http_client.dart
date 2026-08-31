import 'dart:io';

import 'package:dio/dio.dart';
import '../secure_storage/secure_storage_service.dart';
import '../../models/auth_profile/auth_model.dart';
import '../../models/auth_profile/profile_model.dart';
import '../../models/hidden_place/hidden_place_model.dart';
import '../../models/foot_tracker/exploration_model.dart';
import '../../models/post_review/post_model.dart';
import '../../models/hidden_place/recommended_place_model.dart';
import 'package:explore_my/models/foot_tracker/route_model.dart';
import 'package:explore_my/models/foot_tracker/visit_log_model.dart';

class HttpClient {
  HttpClient({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      // Without these, a backend that's down/unreachable (wrong IP, firewall
      // silently dropping packets, etc.) can leave requests hanging instead
      // of failing fast with a DioException the UI can show an error for.
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await _secureStorage.getAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final hasRetriedAuthentication =
              error.requestOptions.extra['authRetryAttempted'] == true;
          final isAuthEndpoint = path == '/api/auth/login' ||
              path == '/api/auth/refresh' ||
              path == '/api/auth/register' ||
              path == '/api/auth/verify-email' ||
              path == '/api/auth/resend-verification' ||
              path == '/api/auth/logout';

          if (error.response?.statusCode == 401 &&
              !isAuthEndpoint &&
              !hasRetriedAuthentication) {
            try {
              final newAccessToken = await _refreshAccessToken();
              final retryRequest = error.requestOptions
                ..headers['Authorization'] = 'Bearer $newAccessToken'
                ..extra['authRetryAttempted'] = true;

              // A FormData body (profile picture upload) is a one-shot stream:
              // replaying the original instance would send an empty or
              // already-finalized body, so hand the retry a fresh clone.
              final data = retryRequest.data;
              if (data is FormData) {
                retryRequest.data = data.clone();
              }

              final response = await _dio.fetch(retryRequest);
              return handler.resolve(response);
            } catch (_) {
              // The session is gone for good: drop the tokens and tell the app
              // so it can return the user to the Login page (FR102-12).
              await _secureStorage.clearTokens();
              onSessionExpired?.call();
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  // Backend base URL.
  // - Android EMULATOR: 10.0.2.2 is a special alias the emulator maps to the host
  //   machine's localhost, so this default works out of the box for `flutter run`
  //   on an emulator.
  // - REAL PHONE (USB or same Wi-Fi): 10.0.2.2 does NOT work - it only means
  //   anything inside the emulator's virtual network. Use the host machine's LAN IP
  //   instead (Windows: `ipconfig`, look for the Wi-Fi adapter's IPv4 address, e.g.
  //   192.168.1.23). The phone and the machine running the backend must be on the
  //   same Wi-Fi network, the backend must be listening on 0.0.0.0 (not just
  //   localhost - see backend/Properties/launchSettings.json), and Windows Firewall
  //   must allow inbound connections on port 5226 (it usually prompts for this the
  //   first time you run the backend).
  // Override this without editing the file:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:5226
  static const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      // defaultValue: 'http://10.0.2.2:5226'
    defaultValue: 'http://0.0.0.0:5226'
  );

  final SecureStorageService _secureStorage;
  late final Dio _dio;
  Future<String>? _refreshFuture;

  /// Called once the stored session can no longer be refreshed — expired,
  /// revoked, or the account was suspended. The app wires this up to sign the
  /// user out locally and send them back to the Login page (FR102-12).
  void Function()? onSessionExpired;

  Future<String> _refreshAccessToken() {
    // Single-flight guard: refresh tokens rotate on every use, so if
    // requests 401 at the same moment, the second must wait for the first
    // refresh instead of firing its own (which would invalidate the first).
    return _refreshFuture ??= _performRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  /// Attempts to silently restore a session from a stored refresh token.
  /// Used at app startup to auto-login without showing the Login screen.
  /// Returns false if there's no stored token or it's no longer valid.
  Future<bool> tryRestoreSession() async {
    try {
      await _refreshAccessToken();
      return true;
    } on DioException {
      return false;
    }
  }

  Future<String> _performRefresh() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) {
      throw DioException(requestOptions: RequestOptions(path: '/api/auth/refresh'));
    }

    final response = await _dio.post('/api/auth/refresh', data: {
      'refreshToken': refreshToken,
    });

    final loginResponse = LoginResponse.fromJson(response.data as Map<String, dynamic>);
    await _secureStorage.saveTokens(
      accessToken: loginResponse.token,
      refreshToken: loginResponse.refreshToken,
    );
    return loginResponse.token;
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _dio.post('/api/auth/login', data: request.toJson());
    return LoginResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RegisterResponse> register(RegisterRequest request) async{
    final response = await _dio.post('/api/auth/register', data: request.toJson());
    return RegisterResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LoginResponse> verifyEmail(VerifyEmailRequest request) async {
    final response = await _dio.post('/api/auth/verify-email', data: request.toJson());
    return LoginResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> resendVerification(ResendVerificationRequest request) async {
    await _dio.post('/api/auth/resend-verification', data: request.toJson());
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/api/auth/logout', data: {'refreshToken': refreshToken});
  }

  /// Signed-out password reset (FR102-13): asks for a code to be emailed to
  /// [email]. Always succeeds, so it cannot reveal whether the account exists.
  Future<void> requestPasswordReset(String email) async {
    await _dio.post('/api/auth/forgot-password', data: {'email': email});
  }

  /// Checks the emailed reset code before the new password is collected
  /// (FR102-17, FR102-18).
  Future<void> verifyForgotPasswordCode(String email, String code) async {
    await _dio.post(
      '/api/auth/forgot-password/verify',
      data: {'email': email, 'code': code},
    );
  }

  /// Stores the new password against a verified reset code (FR102-20).
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post(
      '/api/auth/reset-password',
      data: {'email': email, 'code': code, 'newPassword': newPassword},
    );
  }

  Future<ProfileModel> getProfile() async {
    final response = await _dio.get('/api/profile');
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProfileModel> updateProfile(UpdateProfileRequest request) async {
    final response = await _dio.put('/api/profile', data: request.toJson());
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> requestCurrentEmailVerification() async {
    await _dio.post('/api/profile/email/verify-current/request');
  }

  Future<void> verifyCurrentEmailVerification(String code) async {
    await _dio.post('/api/profile/email/verify-current/confirm', data: {'code': code});
  }

  Future<void> requestEmailChange(String newEmail) async {
    await _dio.post('/api/profile/email/request-change', data: {'newEmail': newEmail});
  }

  Future<ProfileModel> verifyEmailChange(String newEmail, String code) async {
    final response = await _dio.post(
      '/api/profile/email/verify-change',
      data: {'newEmail': newEmail, 'code': code},
    );
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Abandons an in-progress email change so the issued code stops working
  /// (UC103 A3-4).
  Future<void> cancelEmailChange() async {
    await _dio.post('/api/profile/email/cancel-change');
  }

  Future<void> requestPasswordResetCode() async {
    await _dio.post('/api/profile/password/reset-code');
  }

  Future<void> checkCurrentPassword(String currentPassword) async {
    await _dio.post(
      '/api/profile/password/check',
      data: {'currentPassword': currentPassword},
    );
  }

  Future<void> updatePassword({
    required String newPassword,
    String? currentPassword,
    String? resetCode,
  }) async {
    final data = <String, dynamic>{'newPassword': newPassword};
    if (currentPassword != null) data['currentPassword'] = currentPassword;
    if (resetCode != null) data['resetCode'] = resetCode;

    await _dio.put(
      '/api/profile/password',
      data: data,
    );
  }

  Future<void> verifyPasswordResetCode(String code) async {
    await _dio.post('/api/profile/password/reset-code/verify', data: {'code': code});
  }

  Future<ProfileModel> uploadProfilePicture(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });
    final response = await _dio.post('/api/profile/picture', data: formData);
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProfileModel> removeProfilePicture() async {
    final response = await _dio.delete('/api/profile/picture');
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetches hidden-gem places near (latitude, longitude), ranked most-to-least "hidden".
  /// [types] should be Google Places type strings (e.g. "restaurant", "cafe"); omit to
  /// let the backend use its default attractions + food mix.
  Future<List<HiddenPlaceModel>> discoverHiddenPlaces({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    List<String>? types,
    int maxResultCount = 20,
  }) async {
    final response = await _dio.get('/api/hidden-places/discover', queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'maxResultCount': maxResultCount,
      if (types != null && types.isNotEmpty) 'types': types,
    });
    final data = response.data as List<dynamic>;
    return data
        .map((item) => HiddenPlaceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<dynamic> createHiddenPlaceReview({
    String? googlePlaceId,
    String? recommendPlaceId,
    required int rating,
    required String comment,
  }) async {
    final response = await _dio.post(
      '/api/hidden-places/reviews',
      data: {
        'googlePlaceId': googlePlaceId,
        'recommendPlaceId': recommendPlaceId,
        'rating': rating,
        'comment': comment,
      },
    );

    return response.data;
  }

  Future<List<dynamic>> uploadHiddenPlaceReviewPhotos({
    required int reviewId,
    required List<File> files,
  }) async {
    final formData = FormData();

    for (final file in files) {
      final fileName =
          file.path.split(Platform.pathSeparator).last;

      formData.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(
            file.path,
            filename: fileName,
          ),
        ),
      );
    }

    final response = await _dio.post(
      '/api/hidden-places/reviews/$reviewId/photos',
      data: formData,
    );

    return response.data as List<dynamic>;
  }




  Future<dynamic> getMyGooglePlaceReview(
      String googlePlaceId,
      ) async {
    final response = await _dio.get(
      '/api/hidden-places/reviews/google/$googlePlaceId/mine',
    );

    return response.data;
  }

  Future<dynamic> getMyRecommendPlaceReview(
      String recommendPlaceId,
      ) async {
    final response = await _dio.get(
      '/api/hidden-places/reviews/recommend/$recommendPlaceId/mine',
    );

    return response.data;
  }

  Future<void> updateHiddenPlaceReview({
    required int reviewId,
    required int rating,
    required String comment,
  }) async {
    await _dio.put(
      '/api/hidden-places/reviews/$reviewId',
      data: {
        'rating': rating,
        'comment': comment,
      },
    );
  }

  Future<void> deleteHiddenPlaceReview({
    required int reviewId,
  }) async {
    await _dio.delete(
      '/api/hidden-places/reviews/$reviewId',
    );
  }

  Future<void> deleteHiddenPlaceReviewPhoto({
    required int reviewId,
    required int reviewPhotoId,
  }) async {
    await _dio.delete(
      '/api/hidden-places/reviews/$reviewId/photos/$reviewPhotoId',
    );
  }

  Future<void> reportHiddenPlaceReview({
    required int reviewId,
    required String reason,
  }) async {
    await _dio.post(
      '/api/hidden-places/reviews/$reviewId/report',
      data: {
        'reason': reason,
      },
    );
  }

  Future<List<dynamic>> getGooglePlaceReviews(
      String googlePlaceId,
      ) async {
    final response = await _dio.get(
      '/api/hidden-places/reviews/google/$googlePlaceId',
    );

    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getRecommendPlaceReviews(
      String recommendPlaceId,
      ) async {
    final response = await _dio.get(
      '/api/hidden-places/reviews/recommend/$recommendPlaceId',
    );

    return response.data as List<dynamic>;
  }

  //Foot Tracker Modules
  Future<void> addFavouritePlace({
    required String placeId,
    required String name,
    required String primaryType,
    String? address,
    required double latitude,
    required double longitude,
  }) async {
    await _dio.post(
      '/api/foot-tracker/favourite-places',
      data: {
        'placeId': placeId,
        'name': name,
        'primaryType': primaryType,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<List<FavouritePlace>> getFavouritePlaces() async {
    final response = await _dio.get('/api/foot-tracker/favourite-places');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => FavouritePlace.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteFavouritePlaces(List<int> favouritePlaceIds) async {
    await _dio.delete(
      '/api/foot-tracker/favourite-places',
      data: {'favouritePlaceIds': favouritePlaceIds},
    );
  }

  Future<RouteResult> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String profile,
  }) async {
    final response = await _dio.post(
      '/api/foot-tracker/route',
      data: {
        'originLatitude': originLat,
        'originLongitude': originLng,
        'destinationLatitude': destLat,
        'destinationLongitude': destLng,
        'profile': profile,
      },
    );
    return RouteResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> recordVisit({
    String? placeId,
    required String title,
    String? primaryType,
    String? address,
    double? latitude,
    double? longitude,
    double? distanceKm,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    await _dio.post(
      '/api/foot-tracker/visits',
      data: {
        'placeId': placeId,
        'title': title,
        'primaryType': primaryType,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'distanceKm': distanceKm,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
      },
    );
  }

  Future<List<VisitLog>> getVisits() async {
    final response = await _dio.get('/api/foot-tracker/visits');
    return (response.data as List<dynamic>)
        .map((e) => VisitLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> getExplorationMap() async {
    final response = await _dio.get('/api/foot-tracker/exploration-map');
    final data = response.data as Map<String, dynamic>? ?? const {};
    return data.map((key, value) => MapEntry(key, value as int));
  }

  // ============================================================
  // Community Post module
  // ============================================================

  Future<List<PostSummaryModel>> getPostFeed({
    String? category,
    String? type,
    String? sort,
    int? min,
    int? max,
    String? filter,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/api/posts',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (type != null && type.isNotEmpty) 'type': type,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        'min': ?min,
        'max': ?max,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
        'page': page,
        'pageSize': pageSize,
      },
    );
    final list = response.data as List? ?? const [];
    return list
        .map((e) => PostSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PostSummaryModel>> searchPosts(String query,
      {int page = 1, int pageSize = 20}) async {
    final response = await _dio.get(
      '/api/posts/search',
      queryParameters: {'q': query, 'page': page, 'pageSize': pageSize},
    );
    final list = response.data as List? ?? const [];
    return list
        .map((e) => PostSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PostDetailsModel> getPostDetails(String postId) async {
    final response = await _dio.get('/api/posts/$postId');
    return PostDetailsModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PostSummaryModel>> getMyPosts() async {
    final response = await _dio.get('/api/posts/mine');
    final list = response.data as List? ?? const [];
    return list
        .map((e) => PostSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CreatePostResponse> createPost(CreatePostRequest request) async {
    final response = await _dio.post('/api/posts', data: request.toJson());
    return CreatePostResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UpdatePostResponse> updatePost(
      String postId, UpdatePostRequest request) async {
    final response = await _dio.put('/api/posts/$postId', data: request.toJson());
    return UpdatePostResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DeletePostResponse> deletePost(String postId) async {
    final response = await _dio.delete('/api/posts/$postId');
    return DeletePostResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SavePostResponse> savePost(String postId) async {
    final response = await _dio.post('/api/posts/$postId/save');
    return SavePostResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SavePostResponse> unsavePost(String postId) async {
    final response = await _dio.delete('/api/posts/$postId/save');
    return SavePostResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PostSummaryModel>> getSavedPosts({int page = 1, int pageSize = 50}) async {
    final response = await _dio.get(
      '/api/posts/saved',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final list = response.data as List? ?? const [];
    return list
        .map((e) => PostSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EligibleAttractionModel>> getEligibleAttractions() async {
    final response = await _dio.get('/api/posts/eligible-attractions');
    final list = response.data as List? ?? const [];
    return list
        .map((e) => EligibleAttractionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> hasEligibleAttractions() async {
    final response = await _dio.get('/api/posts/eligible-attractions/has');
    final data = response.data as Map<String, dynamic>? ?? const {};
    return data['hasEligibleAttractions'] as bool? ?? false;
  }

  Future<String> uploadPostImage(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path,
          filename: file.uri.pathSegments.last),
    });
    final response = await _dio.post('/api/posts/images/upload', data: formData);
    final data = response.data as Map<String, dynamic>? ?? const {};
    return data['imageUrl'] as String? ?? '';
  }

  Future<List<PostCommentModel>> getMyComments() async {
    final response = await _dio.get('/api/posts/comments/mine');
    final list = response.data as List? ?? const [];
    return list
        .map((e) => PostCommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CreateCommentResponse> createComment(
      String postId, String content) async {
    final response = await _dio.post(
      '/api/posts/$postId/comments',
      data: CreateCommentRequest(content: content).toJson(),
    );
    return CreateCommentResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UpdateCommentResponse> updateComment(
      String commentId, String content) async {
    if (commentId.trim().isEmpty) {
      throw Exception('Comment ID is required to update a comment.');
    }
    final response = await _dio.put(
      '/api/posts/comments/$commentId',
      data: UpdateCommentRequest(content: content).toJson(),
    );
    return UpdateCommentResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DeleteCommentResponse> deleteComment(String commentId) async {
    if (commentId.trim().isEmpty) {
      throw Exception('Comment ID is required to delete a comment.');
    }
    final response = await _dio.delete('/api/posts/comments/$commentId');
    return DeleteCommentResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<ToggleReactionResponse> toggleReaction(String postId) async {
    final response = await _dio.post(
      '/api/posts/$postId/reactions',
      data: const ToggleReactionRequest().toJson(),
    );
    return ToggleReactionResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<List<String>> getReportReasons() async {
    final response = await _dio.get('/api/posts/report-reasons');
    final data = response.data as Map<String, dynamic>? ?? const {};
    return (data['reasons'] as List?)?.cast<String>() ?? const [];
  }

  Future<String> reportPost(String postId, String reason) async {
    final response = await _dio.post(
      '/api/posts/$postId/reports',
      data: CreateReportRequest(reason: reason).toJson(),
    );
    final data = response.data as Map<String, dynamic>? ?? const {};
    return data['reportId'] as String? ?? '';
  }

  Future<List<PostReportModel>> getMyReports() async {
    final response = await _dio.get('/api/posts/reports/mine');
    final list = response.data as List? ?? const [];
    return list
        .map((e) => PostReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecommendedPlaceSummaryModel>> getPublishedPlaces() async {
    final response = await _dio.get('/api/recommended-places/discover');
    final list = response.data as List? ?? const [];
    return list
        .map((e) => RecommendedPlaceSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecommendedPlaceSummaryModel>> getMyRecommendedPlaces() async {
    final response = await _dio.get('/api/recommended-places');
    final list = response.data as List? ?? const [];
    return list
        .map((e) => RecommendedPlaceSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Available Primary Type options for the Recommend Place form, read from
  /// the backend's `hidden_place_cache.primary_type` (read-only data source).
  Future<List<String>> getPrimaryTypes() async {
    final response = await _dio.get('/api/recommended-places/primary-types');
    final list = response.data as List? ?? const [];
    return list.map((e) => e.toString()).toList();
  }

  /// Details of a single recommended place (Place Details).
  Future<RecommendedPlaceDetailsModel> getRecommendedPlaceDetails(String submissionId) async {
    final response = await _dio.get('/api/recommended-places/$submissionId');
    return RecommendedPlaceDetailsModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Upload a place image (JPEG/PNG/WEBP, max 5 MB) and return its public URL.
  /// Used by the recommended place submission flow (Step 1 photos).
  Future<String> uploadRecommendedPlaceImage(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path,
          filename: file.uri.pathSegments.last),
    });
    final response =
        await _dio.post('/api/recommended-places/images/upload', data: formData);
    final data = response.data as Map<String, dynamic>? ?? const {};
    return data['imageUrl'] as String? ?? '';
  }

  Future<SubmitRecommendedPlaceResponse> submitRecommendedPlace(
      SubmitRecommendedPlaceRequest request) async {
    final response = await _dio.post('/api/recommended-places', data: request.toJson());
    return SubmitRecommendedPlaceResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates an existing recommendation (Edit Recommendation). The server updates
  /// BOTH the canonical `recommended_places` row and the `place_submissions`
  /// timestamp in one transaction.
  Future<SubmitRecommendedPlaceResponse> updateRecommendedPlace(
      String submissionId, SubmitRecommendedPlaceRequest request) async {
    final response = await _dio.put('/api/recommended-places/$submissionId', data: request.toJson());
    return SubmitRecommendedPlaceResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WithdrawRecommendedPlaceResponse> withdrawRecommendedPlace(String submissionId) async {
    final response = await _dio.post('/api/recommended-places/$submissionId/withdraw');
    return WithdrawRecommendedPlaceResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Supported PLACE report reasons (NOT post-report reasons).
  Future<List<String>> getRecommendedPlaceReportReasons() async {
    final response = await _dio.get('/api/recommended-places/report-reasons');
    final data = response.data as Map<String, dynamic>? ?? const {};
    return (data['reasons'] as List?)?.cast<String>() ?? const [];
  }

  Future<ToggleVerificationResponse> toggleVerification(
      String submissionId, {required bool verify}) async {
    final response = await _dio.post(
      '/api/recommended-places/$submissionId/verifications',
      data: ToggleVerificationRequest(verify: verify).toJson(),
    );
    return ToggleVerificationResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Records ONE user's PLACE report. Stored server-side in
  /// `hidden_place_suppression` as one row per (user, place). Place Report is
  /// NOT a toggle and NOT an anonymous aggregate: the same user cannot create
  /// a second active report for the same place (backend rejects with 400).
  Future<ReportPlaceResponse> reportPlace(String submissionId, String reason) async {
    final response = await _dio.post(
      '/api/recommended-places/$submissionId/reports',
      data: ReportPlaceRequest(reason: reason).toJson(),
    );
    return ReportPlaceResponse.fromJson(response.data as Map<String, dynamic>);
  }

}

