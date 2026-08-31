import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/foot_tracker/route_model.dart';
import '../../providers/foot_tracker/navigation_provider.dart';
import 'route_map_view.dart';
import 'route_navigation_dialogs.dart';
import 'package:latlong2/latlong.dart' as ll;

/// UC201 - Navigate to Hidden Place
/// Active navigation / route guidance screen (BF-9 to BF-13).
/// Polls GPS every 5 seconds (C4): updates remaining distance/ETA,
/// detects arrival within 50m (C1), and detects deviation from the
/// route beyond 50m (C5), prompting to recalculate or continue (A6).

const _accentColor = Color(0xFFF15A29);
const _dangerColor = Color(0xFFB03A2E);
const double _arrivalRadiusMeters = 50;
const double _deviationThresholdMeters = 50;
const Duration _pollInterval = Duration(seconds: 5);


class RouteNavigationActiveScreen extends StatefulWidget {
  final String destinationName;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final RouteResult route;
  final String profile;
  final String? destinationCategory;
  /// Real place identifier (Google Place ID, or community submission UUID).
  /// Recorded on the visit so PostReview can later match it as an eligible
  /// tagged place. Null when the caller has no valid place id.
  final String? destinationPlaceId;

  const RouteNavigationActiveScreen({
    super.key,
    required this.destinationName,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.route,
    required this.profile,
    required this.destinationCategory,
    this.destinationPlaceId,
  });

  @override
  State<RouteNavigationActiveScreen> createState() => _RouteNavigationActiveScreenState();
}

class _RouteNavigationActiveScreenState extends State<RouteNavigationActiveScreen> {
  final MapController _mapController = MapController();
  Timer? _pollTimer;
  late RouteResult _currentRoute;
  Position? _currentPosition;
  late double _remainingDistanceMeters;
  late double _remainingDurationSeconds;
  late double _initialStraightLineDistance;
  bool _arrived = false;
  bool _isCheckingGps = false;
  bool _deviationAcknowledged = false;
  bool _hasCenteredInitially = false;
  final DateTime _navigationStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.route;
    _initialStraightLineDistance = widget.route.points.isNotEmpty
        ? Geolocator.distanceBetween(
      widget.route.points.first.latitude,
      widget.route.points.first.longitude,
      widget.destinationLat,
      widget.destinationLng,
    )
        : widget.route.distanceMeters;
    _remainingDistanceMeters = widget.route.distanceMeters;
    _remainingDurationSeconds = widget.route.durationSeconds;
    _pollLocation();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollLocation());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  double _distanceToRoute(Position position) {
    if (_currentRoute.points.isEmpty) return 0;
    var minDistance = double.infinity;
    for (final p in _currentRoute.points) {
      final d = Geolocator.distanceBetween(position.latitude, position.longitude, p.latitude, p.longitude);
      if (d < minDistance) minDistance = d;
    }
    return minDistance;
  }

  Future<void> _pollLocation() async {
    if (_arrived || _isCheckingGps) return;
    _isCheckingGps = true;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      final distanceToDestination = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.destinationLat,
        widget.destinationLng,
      );
      final distanceToRoute = _distanceToRoute(position);

      final ratio = _initialStraightLineDistance > 0
          ? (distanceToDestination / _initialStraightLineDistance).clamp(0, 1)
          : 0.0;

      setState(() {
        _currentPosition = position;
        _remainingDistanceMeters = distanceToDestination;
        _remainingDurationSeconds = _currentRoute.durationSeconds * ratio;
      });

      if (!_hasCenteredInitially) {
        _hasCenteredInitially = true;
        _recenterMap();
      }


      if (distanceToDestination <= _arrivalRadiusMeters) {
        await _handleArrival();
        return;
      }

      if (distanceToRoute > _deviationThresholdMeters) {
        if (!_deviationAcknowledged) {
          await _handleDeviation(position);
        }
      } else {
        _deviationAcknowledged = false; // back on route — re-arm future prompts
      }
    } catch (_) {
      _pollTimer?.cancel();
      if (!mounted) return;
      final retry = await showGpsUnavailableDialog(context);
      if (retry == true) {
        _pollTimer = Timer.periodic(_pollInterval, (_) => _pollLocation());
      } else if (mounted) {
        Navigator.of(context).maybePop();
      }
    } finally {
      _isCheckingGps = false;
    }
  }

  void _recenterMap() {
    if (_currentPosition == null) return;
    final heading = _currentPosition!.heading.isNaN ? 0.0 : _currentPosition!.heading;
    try {
      _mapController.move(ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 18);
      _mapController.rotate(-heading);
    } catch (_) {
      // Map not attached — nothing to do.
    }
  }

  Future<void> _recalculateRoute() async {
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      if (mounted) await showGpsUnavailableDialog(context);
      return;
    }

    try {
      final navigationProvider = context.read<NavigationProvider>();
      final newRoute = await navigationProvider.getRoute(
        originLat: position.latitude,
        originLng: position.longitude,
        destLat: widget.destinationLat,
        destLng: widget.destinationLng,
        profile: widget.profile,
      );
      if (!mounted) return;
      setState(() {
        _currentRoute = newRoute;
        _currentPosition = position;
        _remainingDistanceMeters = newRoute.distanceMeters;
        _remainingDurationSeconds = newRoute.durationSeconds;
        _deviationAcknowledged = false; // re-arm auto-deviation checks against the new route
        _initialStraightLineDistance = Geolocator.distanceBetween(
          position.latitude, position.longitude, widget.destinationLat, widget.destinationLng,
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(ll.LatLng(position.latitude, position.longitude), 18);
        } catch (_) {}
      });
    } catch (_) {
      if (mounted) await showRouteRequestFailedDialog(context);
    }
  }

  Future<void> _handleDeviation(Position position) async {
    _pollTimer?.cancel();
    if (!mounted) return;
    final recalculate = await showRouteDeviationDialog(context);

    if (recalculate == true) {
      await _recalculateRoute();
    } else {
      _deviationAcknowledged = true; // user chose to continue — don't keep asking
    }

    if (mounted) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _pollLocation());
    }
  }

  Future<void> _handleArrival() async {
    _arrived = true;
    _pollTimer?.cancel();
    if (!mounted) return;
    try {
      await context.read<NavigationProvider>().recordVisit(
        placeId: widget.destinationPlaceId,
        title: widget.destinationName,
        primaryType: widget.destinationCategory,
        address: widget.destinationAddress,
        latitude: widget.destinationLat,
        longitude: widget.destinationLng,
        distanceKm: _currentRoute.distanceMeters / 1000,
        startedAt: _navigationStartedAt,
        endedAt: DateTime.now(),
      );
    } catch (_) {
      // Non-critical — don't block arrival flow on a failed history write.
    }
    await showArrivalSuccessDialog(context);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
  }

  double get _progress {
    if (_initialStraightLineDistance <= 0) return 1;
    final traveled = _initialStraightLineDistance - _remainingDistanceMeters;
    return (traveled / _initialStraightLineDistance).clamp(0, 1);
  }

  String _formatEta(double seconds) => '${(seconds / 60).round()} min';

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RouteMapView(
              mapController: _mapController,
              destinationLat: widget.destinationLat,
              destinationLng: widget.destinationLng,
              routePoints: _currentRoute.points,
              currentLat: _currentPosition?.latitude,
              currentLng: _currentPosition?.longitude,
              initialZoom: 18,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  backgroundColor: Colors.white,
                  onPressed: _recenterMap,
                  child: const Icon(Icons.my_location, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'recalculate',
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    final confirmed = await showRecalculateRouteConfirmDialog(context);
                    if (confirmed == true) {
                      await _recalculateRoute();
                    }
                  },
                  child: const Icon(Icons.alt_route, color: Colors.black87),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _NavigationInfoCard(
              progress: _progress,
              etaText: _formatEta(_remainingDurationSeconds),
              distanceText: _formatDistance(_remainingDistanceMeters),
              address: widget.destinationAddress,
              onCancelNavigate: () async {
                final confirmed = await showCancelNavigationDialog(context);
                if (confirmed == true) {
                  _pollTimer?.cancel();
                  if (context.mounted) Navigator.of(context).maybePop();
                }
              },
            ),
          ),
          // TEMP: lets you preview every alt-flow dialog without live
          // GPS/API logic. Remove once real triggers call these directly.
          const Positioned(top: 40, right: 16, child: _DebugDialogMenu()),
        ],
      ),
    );
  }
}

class _NavigationInfoCard extends StatelessWidget {
  final double progress;
  final String etaText;
  final String distanceText;
  final String address;
  final VoidCallback onCancelNavigate;

  const _NavigationInfoCard({
    required this.progress,
    required this.etaText,
    required this.distanceText,
    required this.address,
    required this.onCancelNavigate,
  });

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
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: const Color(0xFFEFEFEF),
              valueColor: const AlwaysStoppedAnimation(_accentColor),
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              text: etaText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              children: [
                TextSpan(
                  text: '  $distanceText',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(address, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onCancelNavigate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              label: const Text('Cancel Navigate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugDialogMenu extends StatelessWidget {
  const _DebugDialogMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.bug_report, color: Colors.black45),
      onSelected: (value) {
        switch (value) {
          case 'deviation':
            showRouteDeviationDialog(context);
            break;
          case 'gps':
            showGpsUnavailableDialog(context);
            break;
          case 'already':
            showAlreadyAtDestinationDialog(context);
            break;
          case 'arrived':
            showArrivalSuccessDialog(context);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'deviation', child: Text('Preview: Route deviation')),
        PopupMenuItem(value: 'gps', child: Text('Preview: GPS unavailable')),
        PopupMenuItem(value: 'already', child: Text('Preview: Already at destination')),
        PopupMenuItem(value: 'arrived', child: Text('Preview: Arrival success')),
      ],
    );
  }
}