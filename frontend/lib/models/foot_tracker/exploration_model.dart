class FavouritePlace {
  final String id;
  final String name;
  final String location;
  final String lastVisit;
  final String category;

  const FavouritePlace({
    required this.id,
    required this.name,
    required this.location,
    required this.lastVisit,
    required this.category,
  });

  static const List<String> uiCategories = [
    'Restaurant', 'Cafe', 'Bar', 'Nature', 'Viewpoint', 'Cultural', 'Market', 'Shopping',
  ];

  factory FavouritePlace.fromJson(Map<String, dynamic> json) {
    final lastVisitAt = json['lastVisitAt'] as String?;
    final createdAt = json['createdAt'] as String;
    final date = DateTime.parse(lastVisitAt ?? createdAt);

    return FavouritePlace(
      id: json['favouritePlaceId'].toString(),
      name: json['name'] as String,
      location: (json['address'] as String?) ?? '',
      lastVisit:
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
      category: _mapToUiCategory(json['primaryType'] as String),
    );
  }

  static String _mapToUiCategory(String rawType) {
    // If the DB already stores one of the app's exact 8 categories
    // (e.g. manually-inserted test data), use it as-is.
    for (final c in uiCategories) {
      if (c.toLowerCase() == rawType.toLowerCase()) return c;
    }

    // Otherwise treat it as a raw Google Places `primaryType` value.
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

    return 'Cultural'; // fallback for anything unmapped
  }
}