import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../personal_exploration_map/personal_exploration_map_ui.dart';
import '../exploration_history/exploration_history_ui.dart';
import '../../providers/foot_tracker/exploration_map_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Exploration Feature — entry screen with two tabs:
/// "Personal Exploration Map" (a preview card that opens the full map)
/// and "History" (list of previously visited places, delegated to
/// ExplorationHistoryUi). Matches the Figma mockups.
/// "Has explored" is now driven by real data from ExplorationMapProvider
/// (non-empty per-district visit counts), not a mock toggle.

const _accentColor = Color(0xFFF15A29);

enum _ExplorationTab { personalMap, history }

class ExplorationUi extends StatefulWidget {
  const ExplorationUi({super.key});

  @override
  State<ExplorationUi> createState() => _ExplorationUiState();
}

class _ExplorationUiState extends State<ExplorationUi> {
  _ExplorationTab _selectedTab = _ExplorationTab.personalMap;

  @override
  void initState() {
    super.initState();
    context.read<ExplorationMapProvider>().loadExplorationMap();
  }

  String? _topDistrict(Map<String, int> visitCounts) {
    if (visitCounts.isEmpty) return null;
    final sorted = visitCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<ExplorationMapProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).maybePop()),
            _TabToggle(
              selected: _selectedTab,
              onSelected: (tab) => setState(() => _selectedTab = tab),
            ),
            Expanded(
              child: _selectedTab == _ExplorationTab.personalMap
                  ? _PersonalMapTab(
                isLoading: mapProvider.isLoading,
                hasExplored: mapProvider.visitCounts.isNotEmpty,
                topDistrict: _topDistrict(mapProvider.visitCounts),
                onRetry: () => context.read<ExplorationMapProvider>().loadExplorationMap(),
                onOpenMap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PersonalExplorationMapUi(),
                    ),
                  );
                },
              )
                  : const ExplorationHistoryUi(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
          ),
          const Expanded(
            child: Text(
              'Exploration Feature',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 36), // balances the back button so the title stays centered
        ],
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  final _ExplorationTab selected;
  final ValueChanged<_ExplorationTab> onSelected;

  const _TabToggle({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Personal\nExploration Map',
              isSelected: selected == _ExplorationTab.personalMap,
              onTap: () => onSelected(_ExplorationTab.personalMap),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TabButton(
              label: 'History',
              isSelected: selected == _ExplorationTab.history,
              onTap: () => onSelected(_ExplorationTab.history),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _accentColor : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalMapTab extends StatelessWidget {
  final bool isLoading;
  final bool hasExplored;
  final String? topDistrict;
  final VoidCallback onRetry;
  final VoidCallback onOpenMap;

  const _PersonalMapTab({
    required this.isLoading,
    required this.hasExplored,
    required this.topDistrict,
    required this.onRetry,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Map', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: GestureDetector(
              onTap: hasExplored ? onOpenMap : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.grey.shade200,
                  child: Stack(
                    children: [
                      if (isLoading)
                        const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                      if (!isLoading && hasExplored)
                        Positioned.fill(child: _MapPreviewPlaceholder(topDistrict: topDistrict)),
                      if (!isLoading && !hasExplored)
                        Positioned.fill(
                          child: Center(child: _NoHistoryCard(onRetry: onRetry)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isLoading && hasExplored) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Press to Open Map',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapPreviewPlaceholder extends StatelessWidget {
  final String? topDistrict;

  const _MapPreviewPlaceholder({this.topDistrict});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(3.1945, 101.6965), // Malaysia center
              zoom: 6,
            ),
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            liteModeEnabled: true, // Android: renders as a lightweight static image
          ),
        ),
        if (topDistrict != null)
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Text('Most explored: $topDistrict', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

class _NoHistoryCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _NoHistoryCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No History Found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'You have not explored any hidden places yet. Start discovering hidden places to build your Exploration Map.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}