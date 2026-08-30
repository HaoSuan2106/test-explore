class RoutePoint {
  final double latitude;
  final double longitude;

  const RoutePoint({required this.latitude, required this.longitude});

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class RouteResult {
  final List<RoutePoint> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      points: (json['points'] as List<dynamic>? ?? [])
          .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
    );
  }
}