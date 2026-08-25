import 'dart:io';

import 'package:dio/dio.dart';
import '../secure_storage/secure_storage_service.dart';
import '../../models/auth_profile/auth_model.dart';
import '../../models/auth_profile/profile_model.dart';
import '../../models/hidden_place/hidden_place_model.dart';

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
          final isAuthEndpoint = path == '/api/auth/login' ||
              path == '/api/auth/refresh' ||
              path == '/api/auth/register' ||
              path == '/api/auth/verify-email' ||
              path == '/api/auth/resend-verification' ||
              path == '/api/auth/logout';

          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            try {
              final newAccessToken = await _refreshAccessToken();
              final retryRequest = error.requestOptions
                ..headers['Authorization'] = 'Bearer $newAccessToken';
              final response = await _dio.fetch(retryRequest);
              return handler.resolve(response);
            } catch (_) {
              await _secureStorage.clearTokens();
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
    defaultValue: 'http://10.0.2.2:5226',
  );

  final SecureStorageService _secureStorage;
  late final Dio _dio;
  Future<String>? _refreshFuture;

  Future<String> _refreshAccessToken() {
    // Single-flight guard: refresh tokens rotate on every use, so if two
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

  Future<ProfileModel> getProfile() async {
    final response = await _dio.get('/api/profile');
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProfileModel> updateProfile(UpdateProfileRequest request) async {
    final response = await _dio.put('/api/profile', data: request.toJson());
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
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

  Future<void> requestPasswordResetCode() async {
    await _dio.post('/api/profile/password/reset-code');
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
}