import 'package:flutter/material.dart';
import 'route_navigation_active_ui.dart';

/// UC201 - Navigate to Hidden Place
/// Route preview / travel-mode selection screen (BF-6 to BF-9).
/// UI-only for now — map is a placeholder. Tapping Start pushes into the
/// active navigation screen (BF-9 to BF-13).

enum TravelMode { driving, walking }

class RouteNavigationScreen extends StatefulWidget {
  const RouteNavigationScreen({super.key});

  @override
  State<RouteNavigationScreen> createState() => _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends State<RouteNavigationScreen> {
  TravelMode _selectedMode = TravelMode.walking;

  // Placeholder data — replace with real values returned from the
  // Google Routes API once that service call is implemented (C30 / C3).
  final Map<TravelMode, String> _eta = const {
    TravelMode.driving: '4 min',
    TravelMode.walking: '10 min',
  };
  final String _distance = '500 m';
  final String _routeType = 'Fastest route';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map area — swap this for a real GoogleMap widget once the
          // Maps API key + google_maps_flutter package are set up.
          const Positioned.fill(child: _MapPlaceholder()),
          Align(
            alignment: Alignment.bottomCenter,
            child: _RouteInfoSheet(
              selectedMode: _selectedMode,
              onModeSelected: (mode) => setState(() => _selectedMode = mode),
              eta: _eta,
              distance: _distance,
              routeType: _routeType,
              onClose: () => Navigator.of(context).maybePop(),
              onStart: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RouteNavigationActiveScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFE9E1),
      alignment: Alignment.center,
      child: const Text(
        'Map view\n(Google Maps integration goes here)',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black38),
      ),
    );
  }
}

class _RouteInfoSheet extends StatelessWidget {
  final TravelMode selectedMode;
  final ValueChanged<TravelMode> onModeSelected;
  final Map<TravelMode, String> eta;
  final String distance;
  final String routeType;
  final VoidCallback onClose;
  final VoidCallback onStart;

  const _RouteInfoSheet({
    required this.selectedMode,
    required this.onModeSelected,
    required this.eta,
    required this.distance,
    required this.routeType,
    required this.onClose,
    required this.onStart,
  });

  String get _modeLabel => selectedMode == TravelMode.walking ? 'Walk' : 'Drive';

  static const _accentColor = Color(0xFFF15A29);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header row: selected mode label + close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _modeLabel,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                  ),
                  child: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Travel mode selector (C6: Walking / Driving)
          Row(
            children: [
              _ModeOption(
                icon: Icons.directions_car,
                label: eta[TravelMode.driving]!,
                isSelected: selectedMode == TravelMode.driving,
                accentColor: _accentColor,
                onTap: () => onModeSelected(TravelMode.driving),
              ),
              const SizedBox(width: 24),
              _ModeOption(
                icon: Icons.directions_walk,
                label: eta[TravelMode.walking]!,
                isSelected: selectedMode == TravelMode.walking,
                accentColor: _accentColor,
                onTap: () => onModeSelected(TravelMode.walking),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ETA + distance (C3: Route Display Information)
          Text.rich(
            TextSpan(
              text: eta[selectedMode],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              children: [
                TextSpan(
                  text: ' ($distance)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(routeType, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          // Start button -> opens the active navigation screen
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
              label: const Text(
                'Start',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? accentColor : Colors.grey.shade500;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          if (isSelected) Container(width: 40, height: 2, color: color),
        ],
      ),
    );
  }
}