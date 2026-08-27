/// Draft data carried through the 4-step Recommend Place wizard:
///
///   STEP 1 — Place Details  (name / category / description)
///   STEP 2 — Direct Map Location (fixed center pin → address + lat/lng)
///   STEP 3 — Location Preview
///   STEP 4 — Review → Submit → Success
///
/// The draft is passed between wizard steps as go_router `extra` so no global
/// state is needed. Field names mirror the provider contract
/// (`submitRecommendation`) so Phase 2 wiring stays a straight pass-through.
class RecommendPlaceDraft {
  final String name;
  final String category;
  final String description;

  /// Set in STEP 2 from the location under the fixed center marker.
  String address;
  double? latitude;
  double? longitude;

  RecommendPlaceDraft({
    required this.name,
    required this.category,
    required this.description,
    this.address = '',
    this.latitude,
    this.longitude,
  });

  /// True once STEP 2 has produced a usable location.
  bool get hasLocation =>
      address.isNotEmpty && latitude != null && longitude != null;

  RecommendPlaceDraft copyWith({
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return RecommendPlaceDraft(
      name: name,
      category: category,
      description: description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
