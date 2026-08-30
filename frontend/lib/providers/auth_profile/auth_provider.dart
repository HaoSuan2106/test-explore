import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../api_communication/http_client/http_client.dart';
import '../../api_communication/secure_storage/secure_storage_service.dart';
import '../../models/auth_profile/auth_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required HttpClient httpClient, required SecureStorageService secureStorage})
      : _httpClient = httpClient,
        _secureStorage = secureStorage;

  final HttpClient _httpClient;
  final SecureStorageService _secureStorage;

  AuthStatus status = AuthStatus.unknown;
  bool isLoading = false;
  String? errorMessage;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _httpClient.login(LoginRequest(email: email, password: password));
      await _secureStorage.saveTokens(
        accessToken: response.token,
        refreshToken: response.refreshToken,
      );
      status = AuthStatus.authenticated;
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e);
      status = AuthStatus.unauthenticated;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String username, String email, String password) async{
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _httpClient.register(
        RegisterRequest(username: username, email: email, password: password),
      );
      return true;
    } on DioException catch (e){
      errorMessage = _messageFor(e);
      return false;
    } finally{
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _httpClient.logout(refreshToken);
      } on DioException {
        // Best effort — the server-side session may already be gone (e.g.
        // expired, offline). Still proceed with clearing local state.
      }
    }

    await _secureStorage.clearTokens();
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Attempts to silently resume a session using a stored refresh token, so
  /// the app can skip the Login screen on startup if one is still valid.
  Future<bool> tryAutoLogin() async {
    final restored = await _httpClient.tryRestoreSession();
    if (!restored) {
      await _secureStorage.clearTokens();
    }
    status = restored ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
    return restored;
  }

  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot connect to the backend at ${HttpClient.baseUrl}. '
          'Check that the backend is running and the API address is correct.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// Activates a pending account with the emailed code (FR101-18).
  ///
  /// The backend hands back a session with the response, but registration ends
  /// at the Login page (FR101-19) — so the tokens are deliberately discarded
  /// rather than stored. Keeping them would leave a live session on the device
  /// that nobody ever logged into, and the next app launch would silently
  /// auto-restore it.
  Future<bool> verifyEmail(String email, String code) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _httpClient.verifyEmail(VerifyEmailRequest(email: email, code: code));
      await _secureStorage.clearTokens();
      status = AuthStatus.unauthenticated;
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Marks the session as gone after the stored refresh token stopped working
  /// (expired, revoked, or the account was suspended). Any locally stored
  /// tokens have already been dropped by the HTTP layer at this point.
  Future<void> handleSessionExpired() async {
    if (status == AuthStatus.unauthenticated) return;

    await _secureStorage.clearTokens();
    status = AuthStatus.unauthenticated;
    errorMessage = null;
    notifyListeners();
  }

  /// UC102 FR102-13 — asks for a reset code to be emailed from the signed-out
  /// Forgot Password screen.
  Future<bool> requestPasswordReset(String email) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _httpClient.requestPasswordReset(email);
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// FR102-17 — validates the emailed reset code before a new password may be
  /// entered.
  Future<bool> verifyPasswordResetCode(String email, String code) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _httpClient.verifyForgotPasswordCode(email, code);
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// FR102-20 — stores the new password against the verified reset code.
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _httpClient.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerificationCode(String email) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _httpClient.resendVerification(ResendVerificationRequest(email: email));
      return true;
    } on DioException catch (e) {
      errorMessage = _messageFor(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}