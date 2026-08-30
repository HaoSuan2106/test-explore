import 'package:flutter/foundation.dart';

import '../../api_communication/http_client/http_client.dart';
import '../../models/foot_tracker/route_model.dart';
import '../../models/foot_tracker/visit_log_model.dart';

/// Handles route calculation for UC201 - Navigate to Hidden Place.
class NavigationProvider extends ChangeNotifier {
  NavigationProvider({required HttpClient httpClient}) : _httpClient = httpClient;

  final HttpClient _httpClient;

  Future<RouteResult> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String profile,
  }) {
    return _httpClient.getRoute(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      profile: profile,
    );
  }

  Future<void> recordVisit({
    String? placeId,
    required String title,
    String? primaryType,
    String? address,
    double? latitude,
    double? longitude,
    double? distanceKm,
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    return _httpClient.recordVisit(
      placeId: placeId,
      title: title,
      primaryType: primaryType,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  Future<List<VisitLog>> getVisits() => _httpClient.getVisits();
}