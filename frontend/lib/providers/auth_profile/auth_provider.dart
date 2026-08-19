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
    return 'Something went wrong. Please try again.';
  }

  Future<bool> verifyEmail(String email, String code) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _httpClient.verifyEmail(VerifyEmailRequest(email: email, code: code));
      await _secureStorage.saveTokens(
        accessToken: response.token,
        refreshToken: response.refreshToken,
      );
      status = AuthStatus.authenticated;
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