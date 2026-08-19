import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart';
import '../community/chat_room/communication_ui.dart';
import '../account/account_page_ui.dart';
import '../post_review/post/post_ui.dart';
import 'custom_nav_bar.dart';

/// The app shell. Holds the persistent bottom nav and swaps tab content.
/// Default tab (index 0) is Hidden Place Discovery UI — the map with pins.
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = const [
    HiddenPlaceDiscoveryUI(),
    CommunicationUI(),
    PostUI(),
    AccountUI(),
  ];

  void _onNavTap(int navIndex) {
    setState(() => _selectedIndex = navIndex);
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = _selectedIndex;

    return Scaffold(
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
    );
  }
}