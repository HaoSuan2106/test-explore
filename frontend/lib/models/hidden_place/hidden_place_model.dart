/// Mirrors the backend's HiddenPlaceResponseItemDto
/// (backend/DTOs/HiddenPlace/HiddenPlaceDtos.cs) - one place returned by
/// GET /api/hidden-places/discover, already scored and ranked by the
/// hidden-gem algorithm.
class HiddenPlaceModel {
  const HiddenPlaceModel({
    required this.placeId,
    required this.name,
    required this.primaryType,
    required this.latitude,
    required this.longitude,
    this.rating,
    required this.userRatingCount,
    this.priceLevel,
    required this.hiddenScore,
  });

  final String placeId;
  final String name;
  final String primaryType;
  final double latitude;
  final double longitude;

  /// 0.0-5.0, null if Google has no rating for this place.
  final double? rating;
  final int userRatingCount;

  /// 0 (free) - 4 (very expensive), null if unknown.
  final int? priceLevel;

  /// 0.0-1.0, higher = more "hidden gem". The API response list is already sorted by this, descending.
  final double hiddenScore;

  factory HiddenPlaceModel.fromJson(Map<String, dynamic> json) => HiddenPlaceModel(
        placeId: json['placeId'] as String,
        name: json['name'] as String,
        primaryType: json['primaryType'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        rating: (json['rating'] as num?)?.toDouble(),
        userRatingCount: json['userRatingCount'] as int,
        priceLevel: json['priceLevel'] as int?,
        hiddenScore: (json['hiddenScore'] as num).toDouble(),
      );
}
