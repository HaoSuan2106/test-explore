import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_communication/http_client/http_client.dart';
import 'api_communication/secure_storage/secure_storage_service.dart';
import 'providers/auth_profile/auth_provider.dart';
import 'utilities/onboarding_preferences.dart';
import 'presentation/authentication/login/login_ui.dart';
import 'presentation/navigation/entry_page_ui.dart';
import 'presentation/navigation/main_page.dart';
import 'providers/auth_profile/profile_provider.dart';

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
        ChangeNotifierProvider(create: (_) => AuthProvider(httpClient: httpClient, secureStorage: secureStorage)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(httpClient: httpClient)),
      ],
      child: MaterialApp(
        title: 'ExploreMY',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        home: const _StartupRouter(),
      ),
    );
  }
}

enum _StartupDestination { entry, login, main }

/// Decides the first screen shown: the entry page (first ever launch), the
/// Login screen (no session, or it couldn't be restored), or straight into
/// [MainPage] if a stored session is still valid — so users stay logged in
/// across app restarts instead of having to sign in every time.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  late final Future<_StartupDestination> _destination = _resolve();

  Future<_StartupDestination> _resolve() async {
    final hasSeenEntry = await const OnboardingPreferences().hasSeenEntryPage();
    if (!hasSeenEntry) return _StartupDestination.entry;
    if (!mounted) return _StartupDestination.login;

    final restored = await context.read<AuthProvider>().tryAutoLogin();
    if (!restored) return _StartupDestination.login;
    if (!mounted) return _StartupDestination.main;

    await context.read<ProfileProvider>().loadProfile();
    return _StartupDestination.main;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupDestination>(
      future: _destination,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: SizedBox.shrink());
        }
        switch (snapshot.data!) {
          case _StartupDestination.entry:
            return const EntryPageUi();
          case _StartupDestination.login:
            return const LoginUi();
          case _StartupDestination.main:
            return const MainPage();
        }
      },
    );
  }
}