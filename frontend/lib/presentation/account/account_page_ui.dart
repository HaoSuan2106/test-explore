import 'package:flutter/material.dart';
import '../authentication/login/login_ui.dart';
import '../exploration/exploration_ui.dart';
import '../manage_profile/change_password_ui.dart';
import '../manage_profile/manage_profile_ui.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_profile/auth_provider.dart';
import '../../providers/auth_profile/profile_provider.dart';
import '../../widgets/animated_tap_button.dart';
import '../favourite_place/favourite_place_screen.dart';
import '../navigation/app_navigation.dart';
import '../../providers/session_scoped_provider.dart';


const Color _kOrange = Color(0xFFFF7148);
const Color _kTitleDark = Color(0xFF101C2C);
const Color _kMuted = Color(0xFF64748B);
const Color _kListBorder = Color(0xFFE4BEB7);
const Color _kIconBoxBg = Color(0x1AB41D0E);
const Color _kLogoutBg = Color(0xFFFFDAD6);
const Color _kLogoutText = Color(0xFFBA1A1A);

class AccountUI extends StatefulWidget {
  const AccountUI({super.key});

  @override
  State<AccountUI> createState() => _AccountUIState();
}

class _AccountUIState extends State<AccountUI> {
  @override
  void initState() {
    super.initState();
    // FR103-01: the Account page is responsible for having the profile, rather
    // than assuming whoever navigated here already loaded it. The provider
    // caches, so this is a no-op once the profile is in memory — and it means
    // a failed load at login can still be recovered from here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileProvider>().loadProfile();
    });
  }

  Future<void> _retryLoadProfile() =>
      context.read<ProfileProvider>().loadProfile(forceRefresh: true);

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;
    // Prefers the locally cached copy over the remote URL — see
    // ProfileProvider.avatarImage.
    final avatarImage = profileProvider.avatarImage;

    // A load that failed leaves nothing to show — offer a way back instead of
    // a permanently blank page.
    if (profile == null && profileProvider.errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined, size: 40, color: _kMuted),
                const SizedBox(height: 12),
                Text(
                  profileProvider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: _kMuted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: profileProvider.isLoading ? null : _retryLoadProfile,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 220,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/bgKLCC.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 64, 20, 48),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          profile?.username ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _kTitleDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: _kMuted),
                            const SizedBox(width: 4),
                            Text(
                              profile?.city ?? 'Location not set',
                              style: const TextStyle(fontSize: 14, color: _kMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AnimatedTapButton(
                          onTap: () {
                            Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const ManageProfileUi())
                            );
                          },
                          borderRadius: BorderRadius.circular(9999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(9999)),
                            child: const Text(
                              'Edit Profile',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kListBorder),
                          ),
                          child: Column(
                            children: [
                              _ProfileListItem(
                                icon: Icons.favorite_border,
                                label: 'Favourite Place',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const FavouritePlaceScreen()),
                                  );                                },
                              ),
                              const _ItemDivider(),
                              _ProfileListItem(
                                icon: Icons.explore_outlined,
                                label: 'Exploration Feature',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const ExplorationUi()),
                                  );
                                },
                              ),
                              const _ItemDivider(),
                              _ProfileListItem(
                                icon: Icons.lock_outline,
                                label: 'Change Password',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const ChangePasswordUi()),
                                  );
                                },
                              ),
                              const _ItemDivider(),
                              // 2. CONNECTED: My Recommended Places -> GoRouter via AppNavigation
                              _ProfileListItem(
                                icon: Icons.place_outlined,
                                label: 'My Recommendation Places',
                                onTap: () {
                                  AppNavigation.toMyRecommendedPlaces(context);
                                },
                              ),
                              const _ItemDivider(),
                              _LogoutListItem(onTap: () async {
                                final confirmed = await _confirmLogout(context);
                                if (confirmed != true || !context.mounted) return;

                                await context.read<AuthProvider>().logout();
                                if (!context.mounted) return;
                                // FR103-14: drop every provider's cached data,
                                // not just the profile, so the next person to
                                // sign in on this device sees none of it.
                                clearSessionScopedProviders(context);
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const LoginUi()),
                                      (route) => false,
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 172,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE9FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF8F9FF), width: 4),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarImage != null
                      ? Transform.scale(
                    scale: 1.2,
                    child: Image(
                      image: avatarImage,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 44, color: Colors.white),
                    ),
                  )
                      : const Icon(Icons.person, size: 44, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmLogout(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: _kMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Logout', style: TextStyle(color: _kLogoutText, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _ProfileListItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileListItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTapButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kIconBoxBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: _kOrange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, color: _kTitleDark, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _kMuted),
          ],
        ),
      ),
    );
  }
}

class _LogoutListItem extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutListItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedTapButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _kLogoutBg, shape: BoxShape.circle),
              child: const Icon(Icons.logout, size: 20, color: _kLogoutText),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Logout',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kLogoutText),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _kMuted),
          ],
        ),
      ),
    );
  }
}

class _ItemDivider extends StatelessWidget {
  const _ItemDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: _kListBorder, indent: 16, endIndent: 16);
  }
}