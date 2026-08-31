import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../api_communication/http_client/http_client.dart';
import '../../models/hidden_place/hidden_place_model.dart';
import '../../models/hidden_place/recommended_place_model.dart';
import '../session_scoped_provider.dart';

/// Surfaces the backend's actual error message when one is present, matching
/// the team pattern used in auth_provider.dart / profile_provider.dart.
/// Returns null when there is no server-provided message (e.g. network error),
/// letting the caller fall back to its fixed friendly string.
String? _messageFor(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['message'] is String) {
    return data['message'] as String;
  }
  return null;
}

/// True when [path] is an absolute http/https URL (an already-persisted photo
/// reference from photos_json). Such entries are kept as-is during submit/update
/// instead of being uploaded again as local files.
bool _isRemotePhotoUrl(String path) {
  return path.startsWith('http://') || path.startsWith('https://');
}

/// State manager for the "Hidden Place Recommendation" module
/// (UC502 — Manage Hidden Place Recommendation).
///
/// Follows the established team pattern:
/// - one injected [HttpClient] (`_httpClient`)
/// - public mutable state fields
/// - every loader/mutation uses the same skeleton:
///   set loading -> clear error -> notifyListeners
///   -> try / on DioException / finally
class HiddenPlaceProvider extends ChangeNotifier implements SessionScopedProvider {
  HiddenPlaceProvider({required HttpClient httpClient}) : _httpClient = httpClient;

  final HttpClient _httpClient;

  // ============================================================
  // Nearby hidden-gem places (Discover)
  // ============================================================

  List<HiddenPlaceModel> places = [];

  /// Fetches hidden-gem places near (latitude, longitude) from the backend and replaces
  /// the current list. Backend handles the Google Places call + the hidden-score ranking,
  /// so this is just "ask for places near here" from the UI's point of view.
  Future<void> loadNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    List<String>? types,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      places = await _httpClient.discoverHiddenPlaces(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        types: types,
      );
    } on DioException {
      errorMessage = 'Failed to load hidden places nearby.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // My Recommended Places (UC502)
  // ============================================================

  bool isLoading = false;
  String? errorMessage;

  /// Set to true when [reportPlace] fails with a 409 Conflict (duplicate report
  /// by the same user on the same place). The calling UI can read this to
  /// reflect the already-reported state (disabled card) instead of showing a
  /// long error message. Reset to false at the start of every [reportPlace] call.
  bool lastReportWasDuplicate = false;

  final List<RecommendedPlaceModel> _userRecommendations = [];

  /// Returns non-withdrawn recommendations (the filtered list shown in the UI).
  List<RecommendedPlaceModel> get userRecommendations =>
      _userRecommendations.where((r) => r.status != 'WITHDRAWN').toList();

  int get totalCount => _userRecommendations.where((r) => r.status != 'WITHDRAWN').length;
  int get underVotingCount =>
      _userRecommendations.where((r) => r.status == 'UNDER_VOTING').length;
  int get verifiedCount =>
      _userRecommendations.where((r) => r.status == 'VERIFIED').length;

  // ============================================================
  // Primary Type options (sourced from hidden_place_cache — read-only)
  // ============================================================

  List<String> primaryTypes = [];
  bool isPrimaryTypesLoading = false;
  String? primaryTypesError;

  /// Loads the distinct Primary Type options for the Recommend Place form from the
  /// backend, which reads them from `hidden_place_cache.primary_type` (read-only).
  /// The UI shows exactly what the cache holds — no invented fallback categories.
  Future<void> loadPrimaryTypes() async {
    isPrimaryTypesLoading = true;
    primaryTypesError = null;
    notifyListeners();

    try {
      primaryTypes = await _httpClient.getPrimaryTypes();
    } on DioException {
      primaryTypesError = 'Failed to load Primary Type options.';
    } finally {
      isPrimaryTypesLoading = false;
      notifyListeners();
    }
  }

  RecommendedPlaceModel? getPlaceById(String placeId) {
    try {
      return _userRecommendations.firstWhere((p) => p.id == placeId);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Data loading
  // ============================================================

  /// Loads the current user's own recommendations (REQ502_26/27/28).
  Future<void> loadMyRecommendations() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _userRecommendations
        ..clear()
        ..addAll((await _httpClient.getMyRecommendedPlaces())
            .map(RecommendedPlaceModel.fromApi));
    } on DioException {
      errorMessage = 'Failed to load your recommended places.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Loads a single recommendation's details for the details screen (REQ502_29/30/31).
  /// Returns the loaded place or null if the API call fails.
  Future<RecommendedPlaceModel?> loadRecommendationDetails(String placeId) async {
    try {
      await refreshPlace(placeId);
    } catch (_) {
      return null;
    }
    return getPlaceById(placeId);
  }

  /// Reloads a single place after a mutation so counts/status stay in sync.
  /// Throws [DioException] on failure so callers can surface the error.
  Future<void> refreshPlace(String placeId) async {
    final details = await _httpClient.getRecommendedPlaceDetails(placeId);
    final updated = RecommendedPlaceModel.fromDetails(details);
    final index = _userRecommendations.indexWhere((p) => p.id == placeId);
    if (index >= 0) {
      _userRecommendations[index] = updated;
    } else {
      _userRecommendations.insert(0, updated);
    }
    notifyListeners();
  }

  // ============================================================
  // Mutations
  // ============================================================

  /// Submit a new recommended place (REQ502_1/3/11). Returns the new id or null.
  ///
  /// Step 1 fields priceLevel / businessStatus are forwarded verbatim, and any
  /// locally selected [photoPaths] are uploaded first (via
  /// POST /api/recommended-places/images/upload) so only permanent public URLs
  /// land in photosJson — never local device paths.
  Future<String?> submitRecommendation({
    required String name,
    required String primaryType,
    required String description,
    required double latitude,
    required double longitude,
    int? priceLevel,
    String? businessStatus,
    List<String>? photoPaths,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final photosJson = <String>[];
      for (final path in photoPaths ?? const <String>[]) {
        // Existing public photo URLs (already persisted in photos_json) pass
        // through UNCHANGED — they are never re-uploaded or re-downloaded.
        // Only freshly picked local device paths are uploaded at submit time.
        if (_isRemotePhotoUrl(path)) {
          photosJson.add(path);
          continue;
        }
        final url = await _httpClient.uploadRecommendedPlaceImage(File(path));
        if (url.isNotEmpty) photosJson.add(url);
      }
      final response = await _httpClient.submitRecommendedPlace(
        SubmitRecommendedPlaceRequest(
          name: name.trim(),
          latitude: latitude,
          longitude: longitude,
          primaryType: primaryType,
          description: description.trim(),
          priceLevel: priceLevel,
          businessStatus: businessStatus,
          photosJson: photosJson.isNotEmpty ? photosJson : null,
        ),
      );
      // Re-load the list so the new place appears at the top with server state.
      await loadMyRecommendations();
      return response.submissionId;
    } on DioException catch (e) {
      errorMessage = _messageFor(e) ?? 'Failed to submit your recommendation.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing recommendation (Edit Recommendation). Mirrors
  /// [submitRecommendation] but calls PUT instead of POST, and the server
  /// updates BOTH `recommended_places` (canonical data) and
  /// `place_submissions` (updated_at) in one transaction.
  ///
  /// Returns the submission id on success, or null on failure (errorMessage set).
  Future<String?> updateRecommendation({
    required String submissionId,
    required String name,
    required String primaryType,
    required String description,
    required double latitude,
    required double longitude,
    int? priceLevel,
    String? businessStatus,
    List<String>? photoPaths,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final photosJson = <String>[];
      for (final path in photoPaths ?? const <String>[]) {
        // Edit-mode rule: existing photo URLs pass through unchanged (never
        // re-uploaded / re-downloaded); only newly picked local files upload.
        if (_isRemotePhotoUrl(path)) {
          photosJson.add(path);
          continue;
        }
        final url = await _httpClient.uploadRecommendedPlaceImage(File(path));
        if (url.isNotEmpty) photosJson.add(url);
      }
      final response = await _httpClient.updateRecommendedPlace(
        submissionId,
        SubmitRecommendedPlaceRequest(
          name: name.trim(),
          latitude: latitude,
          longitude: longitude,
          primaryType: primaryType,
          description: description.trim(),
          priceLevel: priceLevel,
          businessStatus: businessStatus,
          photosJson: photosJson.isNotEmpty ? photosJson : null,
        ),
      );
      // Re-load the list so the updated place appears with server state.
      await loadMyRecommendations();
      return response.submissionId;
    } on DioException catch (e) {
      errorMessage = _messageFor(e) ?? 'Failed to update your recommendation.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Withdraw one of the user's own recommendations (REQ502_32/33/34/35).
  Future<bool> withdrawRecommendation(String placeId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _httpClient.withdrawRecommendedPlace(placeId);
      await loadMyRecommendations();
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e) ?? 'Failed to withdraw your recommendation.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Cast (isVerify = true) or withdraw (isVerify = false) a community verification
  /// on a recommended place (REQ502_6/7/9/10/17/18/23/29).
  Future<bool> castVote(String placeId, {required bool isVerify}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _httpClient.toggleVerification(placeId, verify: isVerify);
      await refreshPlace(placeId);
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e) ?? 'Failed to update your vote.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Records a PLACE report. Server-side the report is stored in
  /// `hidden_place_suppression` as ONE row per (user, place) — the backend
  /// derives the reporter from the authenticated JWT, never from the request
  /// body. Returns the updated report state (count + status + server message),
  /// or null on failure (errorMessage is set). A 409 Conflict (same user +
  /// same place already reported) sets [lastReportWasDuplicate] = true so the
  /// UI can flip to the already-reported state instead of showing an error.
  Future<ReportPlaceResponse?> reportPlace(String submissionId, String reason) async {
    lastReportWasDuplicate = false;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _httpClient.reportPlace(submissionId, reason);
      await refreshPlace(submissionId);
      return result;
    } on DioException catch (e) {
      lastReportWasDuplicate = e.response?.statusCode == 409;
      errorMessage = _messageFor(e) ?? 'Failed to report this place.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Loads supported PLACE report reasons from the backend.
  Future<List<String>> loadPlaceReportReasons() async {
    try {
      return await _httpClient.getRecommendedPlaceReportReasons();
    } catch (_) {
      return const [];
    }
  }

  @override
  void clearSessionData() {
    places = [];
    _userRecommendations.clear();
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}
