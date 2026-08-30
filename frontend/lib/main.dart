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

void main() {
  runApp(const ExploreMYApp());
}

class ExploreMYApp extends StatelessWidget {
  const ExploreMYApp({super.key});

  @override
  Widget build(BuildContext context) {
    const secureStorage = SecureStorageService();
    final httpClient = HttpClient(secureStorage: secureStorage);

    return MultiProvider(
      providers: [

        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            httpClient: httpClient,
            secureStorage: secureStorage,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(
            httpClient: httpClient,
          ),
        ),
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



