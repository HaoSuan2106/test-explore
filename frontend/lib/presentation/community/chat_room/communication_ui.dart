import 'package:flutter/material.dart';

import '../community_list/community_list_ui.dart';

/// Tab-root entry point for the Communication module (bottom nav tab). Thin
/// wrapper so [MainPage]'s tab list stays untouched — the real screen is
/// [CommunityListUi].
class CommunicationUI extends StatelessWidget {
  const CommunicationUI({super.key});

  @override
  Widget build(BuildContext context) {
    return const CommunityListUi();
  }
}

typedef CommunicationUi = CommunicationUI;
