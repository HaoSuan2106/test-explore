import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/community/community_model.dart';
import '../../../providers/community/communication_provider.dart';
import '../chat_room/chat_room_ui.dart';
import '../community_details/community_details_ui.dart';

const Color _kOrange = Color(0xFFFF7148);
const Color _kTitleDark = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF94A3B8);
const Color _kBorder = Color(0xFFE4BEB7);

enum _CommunityTab { explore, browse }

/// "Community Chat" screen — Explore/Browse toggle over a list of
/// communities. Covers: View Community List, Join Community Group.
class CommunityListUi extends StatefulWidget {
  const CommunityListUi({super.key});

  @override
  State<CommunityListUi> createState() => _CommunityListUiState();
}

class _CommunityListUiState extends State<CommunityListUi> {
  _CommunityTab _tab = _CommunityTab.explore;
  final _searchController = TextEditingController();
  // null = all states. Applied client-side on Explore Chat (the joined list
  // is already fully loaded) and sent to the backend on Browse Community.
  String? _selectedState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunicationProvider>().loadJoinedCommunities();
    });
  }

  void _setTab(_CommunityTab tab) {
    setState(() => _tab = tab);
    final provider = context.read<CommunicationProvider>();
    if (tab == _CommunityTab.explore) {
      provider.loadJoinedCommunities();
    } else {
      provider.browseCommunities(keyword: _searchController.text, state: _selectedState);
    }
  }

  void _setStateFilter(String? state) {
    setState(() => _selectedState = state);
    if (_tab == _CommunityTab.browse) {
      context.read<CommunicationProvider>().browseCommunities(keyword: _searchController.text, state: state);
    }
  }

  Future<void> _openDetails(int communityId) async {
    final provider = context.read<CommunicationProvider>();
    final detail = await provider.getCommunityDetail(communityId);
    if (detail == null || !mounted) return;

    await CommunityDetailsUi.show(
      context,
      community: detail,
      onJoin: () async {
        final success = await provider.joinCommunity(communityId);
        if (!mounted) return;
        if (success) {
          // Dismiss the "join" sheet before opening the chat room — otherwise
          // it's left sitting underneath in the navigation stack, and closing
          // or leaving the chat later pops straight back into it (still
          // showing the stale, pre-join "Join Chat" button) instead of
          // returning to the community list.
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Community Joined Successfully')),
          );
          _openChatRoom(communityId, detail.name);
        }
      },
    );
  }

  Future<void> _openChatRoom(int communityId, String communityName) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatRoomUi(communityId: communityId, communityName: communityName),
    ));
    if (!mounted) return;
    // Whether the chat was closed with the back button or with "Leave
    // Group", always land back on Explore Chat (and refresh it) rather
    // than wherever the tab happened to be before — e.g. still on Browse
    // Community if that's how the user got here.
    setState(() => _tab = _CommunityTab.explore);
    context.read<CommunicationProvider>().loadJoinedCommunities();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunicationProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTitleDark,
        elevation: 0,
        centerTitle: true,
        title: Text('Community Chat', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _TabPill(
                    label: 'Explore Chat',
                    selected: _tab == _CommunityTab.explore,
                    onTap: () => _setTab(_CommunityTab.explore),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TabPill(
                    label: 'Browse Community',
                    selected: _tab == _CommunityTab.browse,
                    onTap: () => _setTab(_CommunityTab.browse),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (_tab == _CommunityTab.browse) {
                  context.read<CommunicationProvider>().browseCommunities(keyword: value, state: _selectedState);
                } else {
                  setState(() {});
                }
              },
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search communities...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kMuted),
                prefixIcon: const Icon(Icons.search, color: _kMuted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StateChoiceChip(
                    label: 'All States',
                    selected: _selectedState == null,
                    onSelected: () => _setStateFilter(null),
                  ),
                  for (final state in CommunicationProvider.malaysianStates)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _StateChoiceChip(
                        label: state,
                        selected: _selectedState == state,
                        onSelected: () => _setStateFilter(state),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: _kOrange))
                : _tab == _CommunityTab.explore
                    ? _buildExploreList(provider)
                    : _buildBrowseList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreList(CommunicationProvider provider) {
    final keyword = _searchController.text.trim().toLowerCase();
    final list = provider.joinedCommunities.where((c) {
      final matchesKeyword = keyword.isEmpty || c.name.toLowerCase().contains(keyword);
      final matchesState = _selectedState == null || c.state == _selectedState;
      return matchesKeyword && matchesState;
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 40, color: _kMuted),
            const SizedBox(height: 8),
            Text("Haven't joined any communities?", style: GoogleFonts.plusJakartaSans(color: _kMuted)),
            TextButton(
              onPressed: () => _setTab(_CommunityTab.browse),
              child: Text('Click on Browse Community!',
                  style: GoogleFonts.plusJakartaSans(color: _kOrange, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, index) => _CommunityTile(
        community: list[index],
        onTap: () => _openChatRoom(list[index].communityId, list[index].name),
      ),
    );
  }

  Widget _buildBrowseList(CommunicationProvider provider) {
    if (provider.browseResults.isEmpty) {
      return Center(child: Text('No matching community groups found.', style: GoogleFonts.plusJakartaSans(color: _kMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.browseResults.length,
      itemBuilder: (context, index) => _CommunityTile(
        community: provider.browseResults[index],
        onTap: () => _openDetails(provider.browseResults[index].communityId),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kOrange : Colors.transparent,
          border: Border.all(color: _kOrange),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : _kOrange,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// State-filter pill in the horizontal row above the list. Built on Flutter's
/// own ChoiceChip (rather than a hand-rolled InkWell) so tap handling,
/// hit-testing inside a scrollable row, and the selected/unselected visuals
/// are all the framework's well-tested code, not ours.
class _StateChoiceChip extends StatelessWidget {
  const _StateChoiceChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: selected ? Colors.white : _kTitleDark,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      selectedColor: _kOrange,
      side: BorderSide(color: selected ? _kOrange : _kBorder),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({required this.community, required this.onTap});

  final CommunitySummary community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _kOrange.withValues(alpha: 0.12),
              backgroundImage: community.imageUrl != null ? NetworkImage(community.imageUrl!) : null,
              child: community.imageUrl == null ? const Icon(Icons.groups_rounded, color: _kOrange) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(community.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: _kTitleDark)),
                  if (community.state != null || community.area != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: _kOrange),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            [community.state, community.area].whereType<String>().join(' • '),
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kOrange, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    community.lastMessagePreview ?? community.description ?? 'No messages yet',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('Members: ${community.memberCount}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kOrange, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: _kMuted),
          ],
        ),
      ),
    );
  }
}
