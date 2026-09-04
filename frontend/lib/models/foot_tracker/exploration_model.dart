class FavouritePlace {
  final String id;
  final String placeId;
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final String lastVisit;
  final bool hasVisited;
  final String category;
  final String? photoUrl;
  final String? photoAttribution;

  const FavouritePlace({
    required this.id,
    required this.placeId,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.lastVisit,
    required this.hasVisited,
    required this.category,
    this.photoUrl,
    this.photoAttribution,
  });

  static const List<String> uiCategories = [
    'Restaurant', 'Cafe', 'Bar', 'Nature', 'Viewpoint', 'Cultural', 'Market', 'Shopping',
  ];

  factory FavouritePlace.fromJson(Map<String, dynamic> json) {
    final lastVisitAt = json['lastVisitAt'] as String?;
    final createdAt = json['createdAt'] as String;
    final hasVisited = lastVisitAt != null;
    final date = DateTime.parse(lastVisitAt ?? createdAt);

    return FavouritePlace(
      id: json['favouritePlaceId'].toString(),
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      location: (json['address'] as String?) ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      lastVisit:
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
      hasVisited: hasVisited,
      category: mapToUiCategory(json['primaryType'] as String),
      photoUrl: json['photoUrl'] as String?,
      photoAttribution: json['photoAttribution'] as String?,
    );
  }

  static String mapToUiCategory(String rawType) {
    for (final c in uiCategories) {
      if (c.toLowerCase() == rawType.toLowerCase()) return c;
    }
    const restaurant = {'restaurant', 'meal_takeaway', 'meal_delivery', 'fast_food_restaurant', 'fine_dining_restaurant'};
    const cafe = {'cafe', 'coffee_shop', 'bakery'};
    const bar = {'bar', 'night_club', 'pub', 'wine_bar'};
    const nature = {'park', 'national_park', 'nature_preserve', 'garden', 'beach', 'hiking_area', 'campground'};
    const viewpoint = {'tourist_attraction', 'viewpoint', 'scenic_point'};
    const cultural = {'museum', 'art_gallery', 'historical_landmark', 'monument', 'place_of_worship', 'cultural_center'};
    const market = {'market', 'supermarket', 'grocery_store', 'farmers_market'};
    const shopping = {'shopping_mall', 'clothing_store', 'store', 'department_store'};

    if (restaurant.contains(rawType)) return 'Restaurant';
    if (cafe.contains(rawType)) return 'Cafe';
    if (bar.contains(rawType)) return 'Bar';
    if (nature.contains(rawType)) return 'Nature';
    if (viewpoint.contains(rawType)) return 'Viewpoint';
    if (cultural.contains(rawType)) return 'Cultural';
    if (market.contains(rawType)) return 'Market';
    if (shopping.contains(rawType)) return 'Shopping';

    return 'Cultural';
  }
}