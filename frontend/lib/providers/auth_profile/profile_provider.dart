import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../api_communication/http_client/http_client.dart';
import '../../models/auth_profile/profile_model.dart';

String? _messageFor(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['message'] is String) {
    return data['message'] as String;
  }
  return null;
}

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({required HttpClient httpClient}) : _httpClient = httpClient;

  final HttpClient _httpClient;

  ProfileModel? profile;
  bool isLoading = false;
  String? errorMessage;

  /// Fetches the profile once and caches it. Screens that just need to
  /// display it (Account, Edit Profile) call this and get the cached copy
  /// for free after the first load — pass forceRefresh: true after a save.
  Future<void> loadProfile({bool forceRefresh = false}) async {
    if (profile != null && !forceRefresh) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await _httpClient.getProfile();
    } on DioException {
      errorMessage = 'Failed to load profile.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Uploads a new profile photo and updates the cached profile on success.
  Future<bool> updateProfilePicture(File file) async {
    try {
      profile = await _httpClient.uploadProfilePicture(file);
      errorMessage = null;
      notifyListeners();
      return true;
    } on DioException {
      errorMessage = 'Failed to update profile photo.';
      notifyListeners();
      return false;
    }
  }

  /// Removes the current profile photo and updates the cached profile on success.
  Future<bool> removeProfilePicture() async {
    try {
      profile = await _httpClient.removeProfilePicture();
      errorMessage = null;
      notifyListeners();
      return true;
    } on DioException {
      errorMessage = 'Failed to remove profile photo.';
      notifyListeners();
      return false;
    }
  }

  /// Saves username/city/age/gender and updates the cached profile on success.
  /// Email is deliberately excluded — it goes through the verify-change flow.
  Future<bool> updateProfile({
    required String username,
    String? city,
    int? age,
    String? gender,
  }) async {
    try {
      profile = await _httpClient.updateProfile(
        UpdateProfileRequest(username: username, city: city, age: age, gender: gender),
      );
      errorMessage = null;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e) ?? 'Failed to update profile.';
      notifyListeners();
      return false;
    }
  }

  /// Sends a verification code to [newEmail]. The email itself isn't
  /// changed until the code is confirmed via [verifyEmailChange].
  Future<bool> requestEmailChange(String newEmail) async {
    try {
      await _httpClient.requestEmailChange(newEmail);
      errorMessage = null;
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e) ?? 'Could not send verification code.';
      notifyListeners();
      return false;
    }
  }

  /// Confirms [newEmail] with [code] and updates the cached profile on success.
  Future<bool> verifyEmailChange(String newEmail, String code) async {
    try {
      profile = await _httpClient.verifyEmailChange(newEmail, code);
      errorMessage = null;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e) ?? 'Verification failed.';
      notifyListeners();
      return false;
    }
  }

  /// Call on logout so the next user who logs in on this device
  void clear() {
    profile = null;
    errorMessage = null;
    notifyListeners();
  }
}