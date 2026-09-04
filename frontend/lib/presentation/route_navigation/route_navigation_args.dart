import 'navigation_screen.dart' show RouteNavigationScreen;

/// Navigation payload for routing to [RouteNavigationScreen] through GoRouter (P6.1).
class RouteNavigationArgs {
  final String destinationName;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final String? destinationCategory;
  final String? destinationPlaceId;

  const RouteNavigationArgs({
    required this.destinationName,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationCategory,
    this.destinationPlaceId,
  });
}
