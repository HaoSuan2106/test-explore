import '../hidden_place_discovery/hidden_place_discovery_ui.dart' show PlaceData;
import 'place_details_ui.dart' show PlaceReviewTargetType;

/// Navigation payload for opening [PlaceDetailUI] through GoRouter (P6.1).
///
/// Carries the fully-prepared [PlaceData] (the caller still owns the async
/// load via [HiddenPlaceProvider]) plus the review target type, so the router
/// builder can reconstruct the screen from state.extra without re-fetching.
class PlaceDetailArgs {
  final PlaceData place;
  final PlaceReviewTargetType reviewTargetType;

  const PlaceDetailArgs({
    required this.place,
    this.reviewTargetType = PlaceReviewTargetType.google,
  });
}
