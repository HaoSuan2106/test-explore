import 'package:explore_my/presentation/favourite_place/favourite_place_screen.dart';
import 'package:explore_my/presentation/route_navigation/route_navigation_active_ui.dart';
import 'package:explore_my/providers/post_review/post_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_communication/http_client/http_client.dart';
import 'api_communication/secure_storage/secure_storage_service.dart';
import 'providers/auth_profile/auth_provider.dart';
import 'providers/auth_profile/profile_provider.dart';
import 'utilities/onboarding_preferences.dart';
import 'presentation/authentication/login/login_ui.dart';
import 'presentation/navigation/entry_page_ui.dart';
import 'presentation/route_navigation/navigation_screen.dart';
import 'providers/foot_tracker/favourite_provider.dart';
import 'presentation/navigation/main_page.dart';
import 'providers/hidden_place/hidden_place_provider.dart';
import 'presentation/navigation/app_router.dart';
import 'providers/foot_tracker/navigation_provider.dart';
import 'providers/hidden_place/review_provider.dart';
import 'providers/session_scoped_provider.dart';
import 'api_communication/signalr_client/signalr_client.dart';
import 'providers/community/communication_provider.dart';

void main() {
  runApp(const ExploreMYApp());
}

class ExploreMYApp extends StatefulWidget {
  const ExploreMYApp({super.key});

  @override
  State<ExploreMYApp> createState() => _ExploreMYAppState();
}

class _ExploreMYAppState extends State<ExploreMYApp> {
  static const _secureStorage = SecureStorageService();

  late final HttpClient _httpClient;
  late final AuthProvider _authProvider;
  late final ProfileProvider _profileProvider;
  late final SignalrClient _signalrClient;

  @override
  void initState() {
    super.initState();
    _httpClient = HttpClient(secureStorage: _secureStorage);
    _authProvider =
        AuthProvider(httpClient: _httpClient, secureStorage: _secureStorage);
    _profileProvider = ProfileProvider(httpClient: _httpClient);
    // Community module's real-time chat connection. Built once here (not
    // per-build) so it isn't torn down and reconnected every time this
    // widget rebuilds.
    _signalrClient = SignalrClient(secureStorage: _secureStorage);

    // FR102-12: a session that can no longer be refreshed (expired, revoked or
    // suspended mid-use) must not leave the user sitting on signed-in screens
    // — drop the cached data and send them back to Login.
    _httpClient.onSessionExpired = _handleSessionExpired;
  }

  Future<void> _handleSessionExpired() async {
    await _authProvider.handleSessionExpired();

    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      clearSessionScopedProviders(context);
    } else {
      _profileProvider.clearSessionData();
    }

    appRouter.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final httpClient = _httpClient;

    return MultiProvider(
      providers: [

        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _profileProvider),
        ChangeNotifierProvider(
          create: (_) => FavouriteProvider(httpClient: httpClient),
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationProvider(httpClient: httpClient),
        ),
        ChangeNotifierProvider(
          create: (_) => HiddenPlaceProvider(
            httpClient: httpClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReviewProvider(
            httpClient: httpClient,
          ),
        ),
        ChangeNotifierProvider(create: (_) => PostProvider(httpClient: httpClient, demoMode: true)),
        ChangeNotifierProvider(
          create: (_) => CommunicationProvider(httpClient: httpClient, signalrClient: _signalrClient),
        ),
      ],
      child: MaterialApp.router(
        title: 'ExploreMY',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.green,
          useMaterial3: true,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}



