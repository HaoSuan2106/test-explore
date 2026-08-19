import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utilities/onboarding_preferences.dart';
import '../authentication/login/login_ui.dart';

/// The very first screen a user sees when opening the app.
/// Tapping "Get Started" records the choice in local storage
/// (via [OnboardingPreferences]) so this page is never shown again.
class EntryPageUi extends StatelessWidget {
  const EntryPageUi({super.key, this.onboardingPreferences = const OnboardingPreferences()});

  final OnboardingPreferences onboardingPreferences;

  Future<void> _onGetStarted(BuildContext context) async {
    await onboardingPreferences.markEntryPageSeen();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginUi()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 1),
              Expanded(
                flex: 7,
                child: Image.asset(
                  'assets/images/tourist.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.travel_explore,
                    size: 180,
                    color: Colors.black26,
                  ),
                ),
              ),
              const Spacer(flex: 1),
              Text(
                'Your Journey\nStarts Here',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: 35 / 28,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Find amazing hidden destinations, plan memorable trips, '
                  'and experience the beauty of Malaysia beyond the popular '
                  'attractions.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF94A3B8),
                    height: 22.8 / 14,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              _GetStartedButton(onPressed: () => _onGetStarted(context)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recreates `.action-button-button` + `.button-shadow`: a pill button in
/// `#FF7148` with a soft, tinted drop shadow beneath it.
class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onPressed});

  static const _orange = Color(0xFFFF7148);

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _orange.withValues(alpha: 0.3),
                offset: const Offset(0, 4),
                blurRadius: 6,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: _orange.withValues(alpha: 0.3),
                offset: const Offset(0, 10),
                blurRadius: 15,
                spreadRadius: -3,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Get Started',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 28 / 18,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
