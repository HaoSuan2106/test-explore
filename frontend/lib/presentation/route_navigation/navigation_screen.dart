import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/foot_tracker/route_model.dart';
import '../../providers/foot_tracker/navigation_provider.dart';
import 'route_map_view.dart';
import 'route_navigation_active_ui.dart';
import 'route_navigation_dialogs.dart';
import 'dart:async';

const double _arrivalRadiusMeters = 50;
enum TravelMode { driving, walking }


extension TravelModeProfile on TravelMode {
  String get profile => this == TravelMode.walking ? 'foot-walking' : 'driving-car';
}

class RouteNavigationScreen extends StatefulWidget {
  final String destinationName;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final String? destinationCategory;
  /// Real place identifier (Google Place ID, or community submission UUID).
  /// Recorded on the visit so PostReview can later match it as an eligible
  /// tagged place. Null when the caller has no valid place id.
  final String? destinationPlaceId;


  const RouteNavigationScreen({
    super.key,
    required this.destinationName,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationCategory,
    this.destinationPlaceId,
  });

  @override
  State<RouteNavigationScreen> createState() => _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends State<RouteNavigationScreen> {
  final MapController _mapController = MapController();
  TravelMode _selectedMode = TravelMode.walking;
  bool _isLoading = true;
  Position? _currentPosition;
  final Map<TravelMode, RouteResult> _routeCache = {};
  final DateTime _screenOpenedAt = DateTime.now();


  @override
  void initState() {
    super.initState();
    _prepareRoute();
  }

  Future<void> _prepareRoute() async {
    setState(() => _isLoading = true);

    final position = await _getCurrentLocationOrPrompt();
    if (position == null) return;

    setState(() => _currentPosition = position);

    final distanceToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.destinationLat,
      widget.destinationLng,
    );

    if (distanceToDestination <= _arrivalRadiusMeters) {
      if (!mounted) return;
      await showAlreadyAtDestinationDialog(context);
      try {
        await context.read<NavigationProvider>().recordVisit(
          placeId: widget.destinationPlaceId,
          title: widget.destinationName,
          primaryType: widget.destinationCategory,
          address: widget.destinationAddress,
          latitude: widget.destinationLat,
          longitude: widget.destinationLng,
          distanceKm: 0,
          startedAt: _screenOpenedAt,
          endedAt: DateTime.now(),
        );
      } catch (_) {
        // Non-critical — don't block the user on a failed history write.
      }
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    await _fetchBothRoutes(position);
  }

  Future<Position?> _getCurrentLocationOrPrompt() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _handleGpsUnavailable();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      await showLocationPermissionDialog(context);
      if (mounted) Navigator.of(context).maybePop();
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      return _handleGpsUnavailable();
    } catch (_) {
      return _handleGpsUnavailable();
    }
  }

  Future<Position?> _handleGpsUnavailable() async {
    if (!mounted) return null;
    final retry = await showGpsUnavailableDialog(context);
    if (retry == true) {
      return _getCurrentLocationOrPrompt();
    }
    if (mounted) Navigator.of(context).maybePop();
    return null;
  }

  Future<void> _fetchBothRoutes(Position position) async {
    final navigationProvider = context.read<NavigationProvider>();

    try {
      final results = await Future.wait([
        navigationProvider.getRoute(
          originLat: position.latitude,
          originLng: position.longitude,
          destLat: widget.destinationLat,
          destLng: widget.destinationLng,
          profile: TravelMode.driving.profile,
        ),
        navigationProvider.getRoute(
          originLat: position.latitude,
          originLng: position.longitude,
          destLat: widget.destinationLat,
          destLng: widget.destinationLng,
          profile: TravelMode.walking.profile,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _routeCache[TravelMode.driving] = results[0];
        _routeCache[TravelMode.walking] = results[1];
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = _routeCache[_selectedMode];
        if (route != null) fitMapToRoute(_mapController, route.points);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final retry = await showRouteRequestFailedDialog(context);
      if (retry == true) {
        await _fetchBothRoutes(position);
      } else if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _onModeSelected(TravelMode mode) {
    setState(() => _selectedMode = mode);
    final route = _routeCache[mode];
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => fitMapToRoute(_mapController, route.points));
    }
  }

  String _formatEta(double seconds) => '${(seconds / 60).round()} min';

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = _routeCache[_selectedMode];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RouteMapView(
              mapController: _mapController,
              destinationLat: widget.destinationLat,
              destinationLng: widget.destinationLng,
              routePoints: currentRoute?.points ?? const [],
              currentLat: _currentPosition?.latitude,
              currentLng: _currentPosition?.longitude,
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (currentRoute != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _RouteInfoSheet(
                selectedMode: _selectedMode,
                onModeSelected: _onModeSelected,
                etaDriving: _routeCache[TravelMode.driving] != null
                    ? _formatEta(_routeCache[TravelMode.driving]!.durationSeconds)
                    : '--',
                etaWalking: _routeCache[TravelMode.walking] != null
                    ? _formatEta(_routeCache[TravelMode.walking]!.durationSeconds)
                    : '--',
                distance: _formatDistance(currentRoute.distanceMeters),
                routeType: 'Fastest route',
                onClose: () => Navigator.of(context).maybePop(),
                onStart: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RouteNavigationActiveScreen(
                        destinationName: widget.destinationName,
                        destinationAddress: widget.destinationAddress,
                        destinationLat: widget.destinationLat,
                        destinationLng: widget.destinationLng,
                        destinationCategory: widget.destinationCategory,
                        destinationPlaceId: widget.destinationPlaceId,
                        route: currentRoute,
                        profile: _selectedMode.profile,
                      ),
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

class _RouteInfoSheet extends StatelessWidget {
  final TravelMode selectedMode;
  final ValueChanged<TravelMode> onModeSelected;
  final String etaDriving;
  final String etaWalking;
  final String distance;
  final String routeType;
  final VoidCallback onClose;
  final VoidCallback onStart;

  const _RouteInfoSheet({
    required this.selectedMode,
    required this.onModeSelected,
    required this.etaDriving,
    required this.etaWalking,
    required this.distance,
    required this.routeType,
    required this.onClose,
    required this.onStart,
  });

  String get _modeLabel => selectedMode == TravelMode.walking ? 'Walk' : 'Drive';
  String get _selectedEta => selectedMode == TravelMode.walking ? etaWalking : etaDriving;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_modeLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade200),
                  child: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ModeOption(
                icon: Icons.directions_car,
                label: etaDriving,
                isSelected: selectedMode == TravelMode.driving,
                accentColor: _accentColor,
                onTap: () => onModeSelected(TravelMode.driving),
              ),
              const SizedBox(width: 24),
              _ModeOption(
                icon: Icons.directions_walk,
                label: etaWalking,
                isSelected: selectedMode == TravelMode.walking,
                accentColor: _accentColor,
                onTap: () => onModeSelected(TravelMode.walking),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              text: _selectedEta,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              children: [
                TextSpan(
                  text: ' ($distance)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(routeType, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
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
              label: const Text('Start', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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