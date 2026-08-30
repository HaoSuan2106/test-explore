import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/foot_tracker/route_model.dart';

/// Shared OpenStreetMap view for UC201 - Navigate to Hidden Place.
/// Free, no API key required. Draws the route polyline plus destination
/// and (optional) live current-position markers.
class RouteMapView extends StatelessWidget {
  final MapController mapController;
  final double destinationLat;
  final double destinationLng;
  final List<RoutePoint> routePoints;
  final double? currentLat;
  final double? currentLng;
  final double initialZoom;

  const RouteMapView({
    super.key,
    required this.mapController,
    required this.destinationLat,
    required this.destinationLng,
    required this.routePoints,
    this.currentLat,
    this.currentLng,
    this.initialZoom = 14,
  });

  @override
  Widget build(BuildContext context) {
    final destination = ll.LatLng(destinationLat, destinationLng);
    final hasCurrent = currentLat != null && currentLng != null;
    final initialCenter = hasCurrent ? ll.LatLng(currentLat!, currentLng!) : destination;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCenter: initialCenter, initialZoom: initialZoom),      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // TODO: replace with your app's actual applicationId (see
          // android/app/build.gradle.kts) per OSM's tile usage policy.
          userAgentPackageName: 'com.example.explore_my',
        ),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints.map((p) => ll.LatLng(p.latitude, p.longitude)).toList(),
                strokeWidth: 4,
                color: const Color(0xFFF15A29),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: destination,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Color(0xFFB03A2E), size: 36),
            ),
            if (hasCurrent)
              Marker(
                point: ll.LatLng(currentLat!, currentLng!),
                width: 32,
                height: 32,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
              ),
          ],
        ),
      ],
    );
  }
}

/// Fits the map camera to show the full route with some padding.
void fitMapToRoute(MapController controller, List<RoutePoint> points) {
  if (points.isEmpty) return;
  final bounds = LatLngBounds.fromPoints(
    points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList(),
  );
  controller.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)));
}