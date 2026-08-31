import 'package:flutter/material.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart';
import '../community/chat_room/communication_ui.dart';
import '../account/account_page_ui.dart';
import '../post_review/post/post_ui.dart';
import 'custom_nav_bar.dart';

/// The app shell. Holds the persistent bottom nav and swaps tab content.
/// Default tab (index 0) is Hidden Place Discovery UI — the map with pins.
class MainPage extends StatefulWidget {
  /// Optional initial tab index; defaults to 0 (Explore). When the router
  /// passes ?tab=post the initial tab is set to the Post Feed (index 2).
  final int initialTab;
  const MainPage({super.key, this.initialTab = 0});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _selectedIndex;

  /// True while the Post Feed tab has an active inline search (results shown
  /// or text typed). In those states PostUI's own PopScope handles the
  /// system back (clearing the search), so MainPage must not switch tabs.
  bool _postSearchActive = false;

  late final List<Widget> _tabs = [
    const HiddenPlaceDiscoveryUI(),
    const CommunicationUI(),
    PostUI(onSearchActiveChanged: (active) {
      if (mounted && active != _postSearchActive) {
        setState(() => _postSearchActive = active);
      }
    }),
    const AccountUI(),
  ];

  void _onNavTap(int navIndex) {
    setState(() => _selectedIndex = navIndex);
  }

  /// Post Feed tab (index 2) with no active search: system back must switch
  /// to the Explore tab (index 0, HiddenPlaceDiscoveryUI) instead of popping
  /// the /main route and exiting the app.
  bool get _backShouldSwitchToExplore =>
      _selectedIndex == 2 && !_postSearchActive;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = _selectedIndex;

    return PopScope(
      canPop: !_backShouldSwitchToExplore,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _backShouldSwitchToExplore) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _tabs),
        bottomNavigationBar: CustomNavBar(
          selectedIndex: navIndex,
          onTap: _onNavTap,
          items: const [
            NavItemData(icon: Icons.explore_outlined, label: 'Explore'),
            NavItemData(icon: Icons.forum_outlined, label: 'Community'),
            NavItemData(icon: Icons.add_box_outlined, label: 'Post'),
            NavItemData(icon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}