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
    this.businessStatus,
    required this.hiddenScore,
    required this.obscurityScore,
    required this.qualityScore,
    this.photoUrl,
    this.photoAttribution,
    this.formattedAddress,
    this.googleMapsUri,
    this.nationalPhoneNumber,
    this.websiteUri,
    this.photosJson,
    this.regularOpeningHoursJson,
    this.source = 'GOOGLE',
    this.communityStatus,
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
  final String? businessStatus;

  /// 0.0-1.0, higher = more "hidden gem". The API response list is already sorted by this, descending.
  final double hiddenScore;

  /// The obscurity half of [hiddenScore] on its own: 0.0-1.0, higher = fewer people have reviewed this
  /// place compared with similar places nearby.
  ///
  /// Kept separate because [hiddenScore] blends obscurity with rating, so two places that are nothing
  /// alike can share a score - a 25-review museum and a 1663-review temple both scored 0.411 on a real
  /// search. Show these two alongside the score when explaining a ranking to the user; the score on its
  /// own only says "this ranked higher", not why.
  final double obscurityScore;

  /// The quality half of [hiddenScore] on its own: 0.0-1.0, the rating rescaled so the algorithm's
  /// minimum acceptable rating maps to 0 and 5.0 maps to 1. Not the same as [rating] - this is "how far
  /// above the bar", which is what actually moves the score.
  final double qualityScore;

  /// Public URL of the place's photo, served from our own Supabase bucket - NOT from Google.
  ///
  /// Null is normal, not an error: plenty of genuinely obscure places have no photo at all, which is
  /// most of what a hidden-gem search returns. Show a placeholder rather than an empty box.
  final String? photoUrl;

  /// Who took [photoUrl]'s picture. Google's terms require this to be displayed alongside the
  /// image, so if the photo is shown anywhere, this has to be shown with it. Null when Google gave
  /// no attribution.
  final String? photoAttribution;

  final String? formattedAddress;
  final String? googleMapsUri;
  final String? nationalPhoneNumber;
  final String? websiteUri;
  final String? photosJson;
  final String? regularOpeningHoursJson;

  /// Where this place came from: 'GOOGLE' or 'COMMUNITY' (submitted by a user).
  ///
  /// Worth checking before showing any number on this object. A community place has no Google
  /// rating, no review count and no meaningful [hiddenScore] - those fields are zero because there
  /// is nothing to put in them, not because the place scored badly.
  final String source;

  /// For a community place, how far through verification it is: 'VERIFIED' once enough people have
  /// verified it, 'UNDER_VOTING' while it is still waiting. Null for Google places.
  ///
  /// The map returns both kinds so a recommendation shows up for its author immediately, which
  /// means an UNDER_VOTING pin is an unconfirmed claim sitting on the map next to confirmed ones.
  /// Anything that draws these needs to tell them apart - see [isCommunityVerified].
  final String? communityStatus;

  /// True only for a community place that has passed verification. False for a Google place and
  /// for one still under voting, so it is safe to use directly as "is this confirmed".
  bool get isCommunityVerified => communityStatus == 'VERIFIED';

  factory HiddenPlaceModel.fromJson(Map<String, dynamic> json) => HiddenPlaceModel(
        placeId: json['placeId'] as String,
        name: json['name'] as String,
        primaryType: json['primaryType'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        rating: (json['rating'] as num?)?.toDouble(),
        userRatingCount: json['userRatingCount'] as int,
        priceLevel: json['priceLevel'] as int?,
        businessStatus: json['businessStatus'] as String?,
        hiddenScore: (json['hiddenScore'] as num).toDouble(),
        // Default to 0 rather than requiring the key, so an older backend that does not
        // send these yet still parses instead of throwing on every place in the list.
        obscurityScore: (json['obscurityScore'] as num?)?.toDouble() ?? 0.0,
        qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.0,
        photoUrl: json['photoUrl'] as String?,
        photoAttribution: json['photoAttribution'] as String?,
        formattedAddress: json['formattedAddress'] as String?,
        googleMapsUri: json['googleMapsUri'] as String?,
        websiteUri: json['websiteUri'] as String?,
        nationalPhoneNumber: json['nationalPhoneNumber'] as String?,
        photosJson: json['photosJson'] as String?,
        regularOpeningHoursJson: json['regularOpeningHoursJson'] as String?,
        source: json['source'] as String? ?? 'GOOGLE',
        communityStatus: json['communityStatus'] as String?,
      );
}
