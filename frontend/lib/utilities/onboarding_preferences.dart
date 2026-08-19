import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has already dismissed the entry page
/// by tapping "Get Started", so it is only ever shown once.
class OnboardingPreferences {
  const OnboardingPreferences();

  static const _hasSeenEntryKey = 'has_seen_entry_page';

  Future<bool> hasSeenEntryPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenEntryKey) ?? false;
  }

  Future<void> markEntryPageSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenEntryKey, true);
  }
}
