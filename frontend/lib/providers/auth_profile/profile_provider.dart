import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import '../../api_communication/http_client/http_client.dart';
import '../../models/auth_profile/profile_model.dart';
import '../../utilities/error_message.dart';
import '../../utilities/profile_image_cache.dart';
import '../session_scoped_provider.dart';

class ProfileProvider extends ChangeNotifier implements SessionScopedProvider {
  ProfileProvider({
    required HttpClient httpClient,
    ProfileImageCache? imageCache,
  })  : _httpClient = httpClient,
        _imageCache = imageCache ?? ProfileImageCache();

  final HttpClient _httpClient;
  final ProfileImageCache _imageCache;

  ProfileModel? profile;
  bool isLoading = false;
  String? errorMessage;

  /// The downloaded copy of [ProfileModel.profilePictureUrl], kept on the
  /// device so the avatar still renders with no connection.
  File? avatarFile;

  /// What the UI should draw for the user's avatar: the local file when one
  /// has been cached, the remote URL while it hasn't, and null when there is
  /// no picture at all (callers show their placeholder icon).
  ImageProvider? get avatarImage {
    final file = avatarFile;
    if (file != null) return FileImage(file);

    final url = profile?.profilePictureUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);

    return null;
  }

  /// Loads the avatar that is already on disk, without touching the network.
  ///
  /// Called at startup before [loadProfile] so the picture is on screen even
  /// when the profile request itself fails offline.
  Future<void> loadCachedAvatar() async {
    final file = await _imageCache.load();
    if (file == null) return;

    avatarFile = file;
    notifyListeners();
  }

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
      await _syncAvatar();
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
      await _syncAvatar();
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
      await _syncAvatar();
      errorMessage = null;
      notifyListeners();
      return true;
    } on DioException {
      errorMessage = 'Failed to remove profile photo.';
      notifyListeners();
      return false;
    }
  }

  /// Downloads the current [ProfileModel.profilePictureUrl] if the on-disk
  /// copy is missing or belongs to an older picture. Never throws: a failure
  /// just leaves whatever was already cached in place.
  Future<void> _syncAvatar() async {
    avatarFile = await _imageCache.sync(profile?.profilePictureUrl);
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
      errorMessage = messageForError(e) ?? 'Failed to update profile.';
      notifyListeners();
      return false;
    }
  }

  /// Sends a verification code to the caller's current email, to confirm
  /// they still control it before an email change is allowed.
  Future<bool> requestCurrentEmailVerification() async {
    try {
      await _httpClient.requestCurrentEmailVerification();
      errorMessage = null;
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Could not send verification code.';
      notifyListeners();
      return false;
    }
  }

  /// Confirms the current-email [code]. Required before [requestEmailChange]
  /// will succeed.
  Future<bool> verifyCurrentEmailVerification(String code) async {
    try {
      await _httpClient.verifyCurrentEmailVerification(code);
      errorMessage = null;
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Verification failed.';
      notifyListeners();
      return false;
    }
  }

  /// Sends a verification code to [newEmail]. The email itself isn't
  /// changed until the code is confirmed via [verifyEmailChange]. Requires
  /// [verifyCurrentEmailVerification] to have succeeded first.
  Future<bool> requestEmailChange(String newEmail) async {
    try {
      await _httpClient.requestEmailChange(newEmail);
      errorMessage = null;
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Could not send verification code.';
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
      errorMessage = messageForError(e) ?? 'Verification failed.';
      notifyListeners();
      return false;
    }
  }

  /// Confirms the caller's current password before allowing a password change.
  Future<bool> checkCurrentPassword(String currentPassword) async {
    try {
      await _httpClient.checkCurrentPassword(currentPassword);
      errorMessage = null;
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Could not confirm your password.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword({
    required String newPassword,
    String? currentPassword,
    String? resetCode,
  }) async {
    try {
      await _httpClient.updatePassword(
        newPassword: newPassword,
        currentPassword: currentPassword,
        resetCode: resetCode,
      );
      errorMessage = null;
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Could not update your password.';
      notifyListeners();
      return false;
    }
  }

  /// Sends a password-reset verification code to the caller's own registered email.
  Future<bool> requestPasswordResetCode() async {
    try {
      await _httpClient.requestPasswordResetCode();
      errorMessage = null;
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Could not send verification code.';
      notifyListeners();
      return false;
    }
  }

  /// Confirms the password-reset [code] sent to the caller's own email.
  Future<bool> verifyPasswordResetCode(String code) async {
    try {
      await _httpClient.verifyPasswordResetCode(code);
      errorMessage = null;
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Verification failed.';
      notifyListeners();
      return false;
    }
  }

  /// Abandons an in-progress email change so the code that was emailed stops
  /// working (UC103 A3-4). Best effort: the codes expire on their own, so a
  /// failure here must not block the user from leaving the screen.
  Future<void> cancelEmailChange() async {
    try {
      await _httpClient.cancelEmailChange();
    } on DioException {
      // Ignored on purpose — see above.
    }
  }

  /// Call on logout so the next user who logs in on this device
  void clear() {
    profile = null;
    errorMessage = null;
    avatarFile = null;
    // The downloaded picture outlives the session unless it is deleted, and
    // would otherwise greet whoever signs in next.
    _imageCache.clear();
    notifyListeners();
  }

  @override
  void clearSessionData() => clear();
}
