import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../api_communication/location_service/device_location_service.dart';
import '../../models/hidden_place/hidden_place_model.dart';
import '../../providers/hidden_place/hidden_place_provider.dart';
import '../place_details/place_details_ui.dart';

// =============================================================================
// COLORS
// =============================================================================
class AppColors {
  static const coral = Color(0xFFFF6B4A);
  static const coralLight = Color(0xFFFFE4DB);

  // THE marker pin color - deliberately ONE color for every place, whatever its category.
  // A map full of red/green/purple/blue pins reads as noise and competes with the basemap; the
  // category is carried by the glyph inside the pin (see _iconForType) instead of by its color.
  // The pin body is filled with this AND the glyph is drawn in it on a white inner disc (see
  // _MarkerFactory.pin), so it has to stay mid-to-dark to read at ~30px against white.
  // If this ever changes, change it HERE only - nothing else should hard-code a pin color.
  static const pin = Color(0xFF5F6368);

  // The pin color for the ONE currently-selected place. This is the single exception to the
  // one-color rule above, and it's a different axis: it encodes STATE (this is the place you just
  // tapped), not category, so at most one pin on the map is ever this color. Using the app's accent
  // ties it to the mini card that appears at the same moment. Must stay dark enough for the white
  // inner disc and the glyph drawn in this color to read at ~30px.
  static const pinSelected = coral;

  // Pin body for a place the community submitted and verified, rather than one Google returned.
  // A second exception to the one-colour rule, on a third axis again: not category, not selection,
  // but PROVENANCE. Yellow because it has to be obvious at a glance against the grey field - these
  // are the places that exist only in this app, which is the whole pitch.
  static const pinCommunity = Color(0xFFF2B33D);

  // The glyph drawn on a community pin's white inner disc. Deliberately NOT pinCommunity: yellow on
  // white is around 2:1 contrast and the icon all but disappears at ~30px. Google pins can reuse
  // their body colour because it is dark; this one cannot, so body and glyph are separated here.
  static const pinCommunityGlyph = Color(0xFF8A6100);

  static const textDark = Color(0xFF202124);
  static const textGrey = Color(0xFF5F6368);
  static const hairline = Color(0xFFE8E8E8);

  static const cardBg = Color(0xFFFFFFFF);
  static const chipBg = Color(0xFFFFFFFF);

  static const gmapsBlue = Color(0xFF4285F4);
}

// A light, minimalist Google Maps style (JSON style array) so the basemap
// keeps the same soft/clean feel as the original mock instead of the
// default saturated Google styling.
const String _lightMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f5f3ef"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8a8a94"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#f5f3ef"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#e6e2da"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#f6c453"}]},
  {"featureType": "road.arterial", "elementType": "labels", "stylers": [{"visibility": "simplified"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#dce6ea"}]}
]
''';

// =============================================================================
// DATA
// =============================================================================
class PlaceData {
  final String placeId;
  final String title;
  final String category;
  final String imageUrl;
  final IconData icon;
  final LatLng position;

  final double rating;
  final int ratingCount;
  final int? priceLevel;
  final String businessStatus;

  /// Photographer credit for [imageUrl]. Google requires it to be shown wherever the photo is, and
  /// we serve the bytes from our own bucket, so nothing else will attach it for us.
  final String? photoAttribution;

  /// True when this place came from a community submission rather than Google - see AppColors.
  /// pinCommunity. Also means rating/ratingCount are placeholders, not real measurements.
  final bool isCommunity;

  final String? address;
  final String? phoneNumber;
  final String? websiteUri;
  final String? googleMapsUri;
  final String? photosJson;
  final String? regularOpeningHoursJson;

  const PlaceData({
    required this.placeId,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.icon,
    required this.position,
    required this.rating,
    required this.ratingCount,
    required this.priceLevel,
    required this.businessStatus,
    this.photoAttribution,
    this.isCommunity = false,
    required this.address,
    required this.phoneNumber,
    required this.websiteUri,
    required this.googleMapsUri,
    required this.photosJson,
    required this.regularOpeningHoursJson,
  });
}

// Fallback origin used until the device's real GPS position comes back (or if location
// permission is denied / services are off) - keeps the map centered somewhere sensible
// instead of the middle of the ocean at (0, 0).
const _center = LatLng(3.1390, 101.6869); // Kuala Lumpur-ish, adjust freely

// The Explore Places sheet has exactly two resting positions, as fractions of screen height.
//
// _kSheetRestExtent doubles as the sheet's MAXIMUM, which is what makes this a pull-down-only
// sheet: it can be dragged out of the way to see the whole map and let go to spring back, but it
// never grows past its resting size. The card row is a fixed-height horizontal carousel, so
// letting it expand would just add empty space under the cards.
//
// _kSheetCollapsedExtent leaves the grab handle and the "Explore Places" heading peeking above
// the bottom nav - dragging to a sliver of nothing would leave the user with no obvious way back.
//
// _kSheetRestExtent is also what sets the place photo's height. Everything else in a card - the
// title, the category line, the gaps - is fixed, and the photo is the one flexible part, so it
// absorbs the whole difference. Raise this number for taller photos, lower it for shorter ones
// and more visible map.
const double _kSheetRestExtent = 0.42;
const double _kSheetCollapsedExtent = 0.13;

// The search radii the user can pick between - must match the backend's
// [AllowedValues(2_500, 5_000)] on DiscoverHiddenPlaceRequestDto.RadiusMeters, or the request is
// rejected as invalid. Keeping this a closed set (rather than a free-form slider) means every search
// this screen makes lands on one of the radii the backend's grid cache is actually tuned for - see
// SearchGridPlanner.
const List<int> _radiusOptionsMeters = [2500, 5000];

/// Formats a radius in metres as a short km label: 2500 -> "2.5km", 5000 -> "5km".
/// Deliberately not `meters ~/ 1000` - integer division truncates, so it would render 2500 as "2km",
/// silently mislabelling half the options.
String _formatKm(int meters) {
  final km = meters / 1000;
  return km == km.truncateToDouble()
      ? '${km.toInt()}km'
      : '${km.toStringAsFixed(1)}km';
}

/// Internal key for the radius chip. It's a cycler rather than a toggle, so it's the one chip whose
/// key is not a Google Places type string and whose tap doesn't touch _selectedTypes.
const String _radiusChipKey = 'radius';

/// The place types the user can filter by. Each key is the exact Google Places type string the
/// backend expects in the request's `types` list.
///
/// Deliberately kept a subset of HiddenPlaceService.DefaultTypes: those are the types an unfiltered
/// search already fetches and caches, and the cache is bucketed per type ("cafe:118:5761"), so
/// narrowing to any of them is served entirely from cache - no extra Google call, no extra cost.
/// A type that is NOT in DefaultTypes would still work here, but selecting it the first time would
/// have to hit Google for every cell in range before showing anything.
const List<_FilterChipData> _typeFilters = [
  _FilterChipData('tourist_attraction', 'Attraction', Icons.attractions),
  _FilterChipData('restaurant', 'Restaurant', Icons.restaurant),
  _FilterChipData('cafe', 'Cafe', Icons.local_cafe),
  _FilterChipData('museum', 'Museum', Icons.museum),
  _FilterChipData('scenic_spot', 'Scenic', Icons.landscape),
];

/// Picks a marker glyph for a place from its Google Places primary type. Places API doesn't hand us
/// an icon, so this is our own mapping.
///
/// The glyph is the ONLY thing that varies per category - a pin is drawn in AppColors.pin, or
/// AppColors.pinSelected while it's the selected one. Don't reintroduce a per-category colour here.
///
/// The type we get back is the place's OWN primaryType, which is almost always more specific than
/// the type that was searched for: a "cafe" search returns coffee_shop / bakery / tea_house /
/// dessert_shop, and a "restaurant" search returns one of roughly a hundred cuisine-specific types
/// (japanese_restaurant, seafood_restaurant, ...). Enumerating all of them is hopeless, so the
/// switch covers the types worth a distinct glyph and the suffix rules underneath catch the long
/// tail - including types Google adds after this was written. Only genuinely unknown types fall
/// through to a generic pin glyph, so a wrong-looking icon means a missing rule, not a missing type.
///
/// Type reference: https://developers.google.com/maps/documentation/places/web-service/place-types
IconData _iconForType(String primaryType) {
  switch (primaryType) {
  // --- Food ---
    case 'restaurant':
    case 'fine_dining_restaurant':
    case 'meal_takeaway':
    case 'meal_delivery':
    case 'food_court':
      return Icons.restaurant;
    case 'fast_food_restaurant':
    case 'hamburger_restaurant':
      return Icons.lunch_dining;
    case 'pizza_restaurant':
      return Icons.local_pizza;
    case 'seafood_restaurant':
      return Icons.set_meal;
    case 'bar':
    case 'pub':
    case 'wine_bar':
    case 'brewery':
    case 'winery':
      return Icons.local_bar;

  // --- Cafe / drinks / sweets ---
    case 'cafe':
    case 'coffee_shop':
    case 'tea_house':
      return Icons.local_cafe;
    case 'bakery':
    case 'dessert_shop':
    case 'donut_shop':
      return Icons.bakery_dining;
    case 'ice_cream_shop':
      return Icons.icecream;

  // --- Culture / history ---
    case 'museum':
    case 'history_museum':
    case 'art_museum':
    case 'planetarium':
      return Icons.museum;
    case 'art_gallery':
    case 'art_studio':
    case 'sculpture':
      return Icons.palette;
    case 'performing_arts_theater':
    case 'opera_house':
    case 'concert_hall':
    case 'amphitheatre':
      return Icons.theater_comedy;
    case 'historical_place':
    case 'historical_landmark':
    case 'cultural_landmark':
    case 'monument':
    case 'castle':
    case 'place_of_worship':
      return Icons.account_balance;

  // --- Attractions ---
    case 'tourist_attraction':
    case 'visitor_center':
    case 'plaza':
      return Icons.attractions;
    case 'observation_deck':
      return Icons.visibility;
    case 'amusement_park':
    case 'amusement_center':
      return Icons.celebration;
    case 'water_park':
      return Icons.pool;
    case 'zoo':
    case 'wildlife_park':
    case 'wildlife_refuge':
      return Icons.pets;
  // Not Icons.set_meal - that's the fish-on-a-plate glyph already used for seafood_restaurant.
  // With every pin the same colour the glyph is the only thing telling them apart, so reusing one
  // would make an aquarium read as a seafood restaurant.
    case 'aquarium':
      return Icons.waves;

  // --- Nature / scenic ---
    case 'scenic_spot':
    case 'observation_point':
      return Icons.landscape;
    case 'park':
    case 'national_park':
    case 'state_park':
    case 'picnic_ground':
    case 'dog_park':
      return Icons.park;
    case 'garden':
    case 'botanical_garden':
      return Icons.local_florist;
    case 'beach':
      return Icons.beach_access;
    case 'hiking_area':
    case 'mountain_peak':
    case 'natural_feature':
    case 'nature_preserve':
    case 'woods':
      return Icons.terrain;
    case 'lake':
    case 'river':
    case 'island':
      return Icons.water;
    case 'marina':
      return Icons.sailing;

  // --- Shopping / markets ---
    case 'market':
    case 'farmers_market':
    case 'flea_market':
      return Icons.storefront;
    case 'shopping_mall':
    case 'department_store':
    case 'store':
      return Icons.shopping_bag;
    case 'gift_shop':
    case 'book_store':
      return Icons.card_giftcard;
  }

  // Long tail. Google's type list is mostly "<something>_restaurant" / "<something>_store" style
  // variants, so matching on the suffix keeps a type we've never seen landing on the right glyph
  // instead of dropping to the generic pin.
  if (primaryType.endsWith('_restaurant')) {
    return Icons.restaurant;
  }
  if (primaryType.endsWith('_museum')) {
    return Icons.museum;
  }
  if (primaryType.endsWith('_gallery')) {
    return Icons.palette;
  }
  if (primaryType.endsWith('_park')) {
    return Icons.park;
  }
  if (primaryType.endsWith('_store') || primaryType.endsWith('_shop')) {
    return Icons.storefront;
  }

  return Icons.place;
}

String _humanizeType(String primaryType) {
  final words = primaryType.split('_');
  return words
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Maps a raw API result (HiddenPlaceModel) to this screen's presentation model (PlaceData).
/// Places API photos aren't wired up on the backend yet, so imageUrl is left blank and the
/// UI falls back to _PhotoPlaceholder (see _PlaceCard/_MiniPlaceCard errorBuilder).
PlaceData _toPlaceData(HiddenPlaceModel place) {
  return PlaceData(
    placeId: place.placeId,
    title: place.name,
    category: _humanizeType(place.primaryType),
    // Empty string, not null, when the place has no photo - _PlaceCard treats empty as "show the
    // placeholder" and never asks the network for it.
    imageUrl: place.photoUrl ?? '',
    icon: _iconForType(place.primaryType),
    position: LatLng(
      place.latitude,
      place.longitude,
    ),
    rating: place.rating ?? 0.0,
    ratingCount: place.userRatingCount,
    priceLevel: place.priceLevel,
    businessStatus: place.businessStatus ?? 'UNKNOWN',
    photoAttribution: place.photoAttribution,
    isCommunity: place.source == 'COMMUNITY',

    address: place.formattedAddress,
    phoneNumber: place.nationalPhoneNumber,
    websiteUri: place.websiteUri,
    googleMapsUri: place.googleMapsUri,

    photosJson: place.photosJson,
    regularOpeningHoursJson: place.regularOpeningHoursJson,
  );
}

// =============================================================================
// MARKER BITMAP GENERATOR
// Google Maps native markers can't embed arbitrary widgets, so we rasterize
// a teardrop pin into a PNG and hand it to BitmapDescriptor.
//
// The fill is AppColors.pin, or AppColors.pinSelected for the single selected place - the pin still
// doesn't take a colour parameter, so there is no way for a call site to slip a per-category colour
// back in. Only the glyph, the size and the selected state vary.
// =============================================================================
class _MarkerFactory {
  static Future<BitmapDescriptor> pin({
    required IconData icon,
    bool selected = false,
    bool community = false,
  }) async {
    // Selection wins over provenance: at most one pin on the map is ever coral, and losing the
    // yellow for as long as its card is open is a smaller cost than having two "special" colours
    // on screen at once with no way to tell which one means what.
    final color = selected
        ? AppColors.pinSelected
        : community
            ? AppColors.pinCommunity
            : AppColors.pin;

    final glyphColor = !selected && community ? AppColors.pinCommunityGlyph : color;
    final double size = selected ? 64 : 52;
    final double tailExtra = 16;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size, size + tailExtra),
    );

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 6;

    // soft drop shadow
    canvas.drawCircle(
      center.translate(0, 5),
      radius,
      Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );

    // teardrop body = circle unioned with a triangular tail
    final body = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final tail = Path()
      ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.65)
      ..lineTo(center.dx, size + tailExtra - 6)
      ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.65)
      ..close();
    final pin = Path.combine(ui.PathOperation.union, body, tail);

    canvas.drawPath(pin, Paint()..color = color);
    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // inner white disc
    canvas.drawCircle(center, radius * 0.6, Paint()..color = Colors.white);

    // icon glyph, rendered via the Material icon font
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: radius * 0.72,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: glyphColor,
      ),
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.toInt(),
      (size + tailExtra).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// The "you are here" dot. Deliberately smaller than the place pins - it marks where the search is
  /// centred, it is not one of the results, so it should not compete with them for attention.
  ///
  /// To resize: change the two radii together and keep size >= outer * 2 + 2, otherwise the canvas
  /// crops the circle. The gap between them is the white ring, which is what keeps the dot readable
  /// against both the beige land and the blue water in _lightMapStyle.
  static Future<BitmapDescriptor> userDot() async {
    const double outerRadius = 13; // white ring
    const double innerRadius = 10; // blue core
    const double size = outerRadius * 2 + 4;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final center = const Offset(size / 2, size / 2);

    canvas.drawCircle(center, outerRadius, Paint()..color = Colors.white);
    canvas.drawCircle(center, innerRadius, Paint()..color = AppColors.gmapsBlue);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}

// =============================================================================
// SCREEN
// =============================================================================
class HiddenPlaceDiscoveryUI extends StatefulWidget {
  const HiddenPlaceDiscoveryUI({super.key});

  @override
  State<HiddenPlaceDiscoveryUI> createState() => _HiddenPlaceDiscoveryUIState();
}

class _HiddenPlaceDiscoveryUIState extends State<HiddenPlaceDiscoveryUI>
    with SingleTickerProviderStateMixin {
  // Google Places types the user has narrowed to. EMPTY MEANS "no filter" - i.e. show everything -
  // not "show nothing": an empty set sends no `types` at all, letting the backend fall back to its
  // full DefaultTypes mix. That's why toggling the last active chip off restores the full list.
  final Set<String> _selectedTypes = {};
  int _navIndex = 0;
  PlaceData? _selectedPlace;
  bool _showPlaceDetail = false;
  bool _mapReady = false;

  List<PlaceData> _places = [];
  bool _isLoadingPlaces = true;
  String? _placesError;

  // Which of _radiusOptionsMeters is currently active. Written out rather than taken from
  // _radiusOptionsMeters.first so reordering or extending that list can't silently change what the
  // screen opens on. Must be a value the backend's [AllowedValues] accepts, or the first search of
  // every session fails validation.
  int _radiusMeters = 2500;

  // Starts as the fallback constant; _loadPlaces() overwrites it with the device's
  // real GPS position when available, before the map/markers are ever built.
  LatLng _searchOrigin = _center;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  BitmapDescriptor? _userIcon;

  // Marker bitmaps only depend on (icon, selected) - not on which specific place they're for - and
  // there are only a handful of distinct combinations (one per glyph in _iconForType). Caching
  // them means switching radius (or re-selecting a place) reuses already-rasterized bitmaps instead of
  // redrawing a canvas + encoding a PNG for every single place on every fetch, which was the main
  // reason the map felt slow (1-2s) whenever the radius chip was toggled.
  final Map<String, BitmapDescriptor> _pinIconCache = {};
  Future<BitmapDescriptor>? _userIconFuture;

  Future<BitmapDescriptor> _pinIconFor(
      PlaceData place, {
        required bool selected,
      }) async {
    // isCommunity is part of the key, not just selected: the same glyph is rasterised in two
    // different colours depending on where the place came from, and without it the first place of a
    // given type to be drawn would decide the colour for every other place sharing that icon.
    final key = '${place.icon.codePoint}_${selected}_${place.isCommunity}';
    final cached = _pinIconCache[key];
    if (cached != null) return cached;
    final icon = await _MarkerFactory.pin(
      icon: place.icon,
      selected: selected,
      community: place.isCommunity,
    );
    _pinIconCache[key] = icon;
    return icon;
  }

  /// How much of the screen the Explore sheet currently covers, 0.0-1.0.
  ///
  /// A ValueNotifier rather than setState: this changes on every frame of a drag, and the map
  /// controls are the only things that need to move with it. Calling setState here would rebuild
  /// the GoogleMap and the whole marker set 60 times a second for a couple of floating buttons.
  final ValueNotifier<double> _sheetExtent = ValueNotifier(_kSheetRestExtent);

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  // Built fresh on every build() rather than kept as a static const list, since the radius chip's
  // label needs to reflect the currently-selected radius (e.g. "2.5km radius").
  List<_FilterChipData> get _filters => [
    _FilterChipData(
      _radiusChipKey,
      '${_formatKm(_radiusMeters)} radius',
      Icons.radar,
    ),
    ..._typeFilters,
  ];

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  /// Gets the device's real GPS position (falling back to _center if location is
  /// unavailable/denied), then fetches nearby hidden-gem places from the backend
  /// (Google Places API + the hidden-score algorithm) centered on that point, and
  /// rebuilds the map pins.
  Future<void> _loadPlaces() async {
    final position = await const DeviceLocationService().getCurrentPosition();
    if (mounted && position != null) {
      setState(
            () => _searchOrigin = LatLng(position.latitude, position.longitude),
      );
    }
    await _fetchPlaces();
  }

  /// Re-fetches places for the current _searchOrigin + _radiusMeters + _selectedTypes, without
  /// touching GPS - used when the user just changes a chip and doesn't need a fresh location fix.
  Future<void> _fetchPlaces() async {
    if (mounted) {
      setState(() => _isLoadingPlaces = true);
    }

    final provider = context.read<HiddenPlaceProvider>();
    await provider.loadNearby(
      latitude: _searchOrigin.latitude,
      longitude: _searchOrigin.longitude,
      radiusMeters: _radiusMeters,
      // null (not an empty list) when nothing is selected, so the backend uses its full default mix.
      types: _selectedTypes.isEmpty ? null : _selectedTypes.toList(),
    );
    if (!mounted) return;
    setState(() {
      _places = provider.places.map(_toPlaceData).toList();
      _isLoadingPlaces = false;
      _placesError = provider.errorMessage;
    });
    await _buildMarkers();
  }

  /// Cycles forward through the allowed radius options (2.5km -> 5km -> back to 2.5km) and re-fetches.
  /// Tapping the chip repeatedly is the only way to reach a given radius, so keep _radiusOptionsMeters
  /// short enough that wrapping around stays quick - with two options the chip is simply a toggle.
  void _toggleRadius() {
    final currentIndex = _radiusOptionsMeters.indexOf(_radiusMeters);
    final nextIndex = (currentIndex + 1) % _radiusOptionsMeters.length;
    setState(() => _radiusMeters = _radiusOptionsMeters[nextIndex]);
    _fetchPlaces();
  }

  /// Adds/removes one Google Places type from the filter and re-fetches. Turning every chip off is
  /// the "show everything" state, not an empty result - see _selectedTypes.
  ///
  /// This re-queries the backend rather than filtering _places in memory on purpose: Google returns
  /// each place's own primaryType, which often isn't the type that was asked for (a "cafe" search
  /// can come back with primaryType "coffee_shop" or "bakery"), so filtering the loaded list by
  /// primaryType would silently drop legitimate matches. Narrowing to types already covered by the
  /// backend's DefaultTypes is a pure cache hit anyway - see _typeFilters.
  void _toggleType(String googleType) {
    setState(() {
      if (!_selectedTypes.remove(googleType)) {
        _selectedTypes.add(googleType);
      }
    });
    _fetchPlaces();
  }

  Future<void> _buildMarkers() async {
    // The user-location dot never changes, so only ever build it once and reuse the same Future for
    // every subsequent call (e.g. every radius toggle) instead of re-rasterizing it each time.
    final userIcon = await (_userIconFuture ??= _MarkerFactory.userDot());

    // Build every place's marker bitmap concurrently (and via the cache in _pinIconFor) instead of
    // awaiting them one at a time - with ~10-20 places that sequential loop was the main source of the
    // 1-2s pause whenever the radius chip was switched.
    // A place can still be selected while this runs (e.g. the user tapped a pin, then changed a
    // filter chip), so carry that state into the rebuilt bitmap - otherwise the selected place would
    // quietly lose its highlight colour while its mini card is still on screen.
    final selectedPlaceId = _selectedPlace?.placeId;
    final icons = await Future.wait(
      _places.map(
            (place) =>
            _pinIconFor(place, selected: place.placeId == selectedPlaceId),
      ),
    );

    final built = <Marker>{
      for (var i = 0; i < _places.length; i++)
        Marker(
          markerId: MarkerId(_places[i].placeId),
          position: _places[i].position,
          icon: icons[i],
          anchor: const Offset(0.5, 1.0),
          zIndex: _places[i].placeId == selectedPlaceId ? 5 : 0,
          onTap: () => _selectPlace(_places[i]),
        ),
    };

    built.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: _searchOrigin,
        icon: userIcon,
        anchor: const Offset(0.5, 0.5),
        zIndex: 10,
      ),
    );

    if (!mounted) return;
    setState(() {
      _userIcon = userIcon;
      _markers
        ..clear()
        ..addAll(built);
      _mapReady = true;
    });
  }

  /// Rebuilds one place's marker in the given state (selected = big + AppColors.pinSelected,
  /// unselected = normal size + AppColors.pin) and swaps it into _markers. Shared by
  /// _selectPlace/_deselect so a marker always gets reverted the same way it got highlighted,
  /// instead of each call site duplicating the marker-rebuild logic.
  Future<void> _setMarkerSelected(PlaceData place, bool selected) async {
    final icon = await _pinIconFor(place, selected: selected);
    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == place.placeId);
      _markers.add(
        Marker(
          markerId: MarkerId(place.placeId),
          position: place.position,
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          // Lift the highlighted pin above its neighbours so the colour change is actually visible
          // in a dense cluster, but keep it under the user-location dot (zIndex 10).
          zIndex: selected ? 5 : 0,
          onTap: () => _selectPlace(place),
        ),
      );
    });
  }

  Future<void> _selectPlace(PlaceData place) async {
    final previouslySelected = _selectedPlace;

    setState(() {
      _selectedPlace = place;
      _showPlaceDetail = true;
    });

    if (previouslySelected != null &&
        previouslySelected.placeId != place.placeId) {
      await _setMarkerSelected(previouslySelected, false);
    }

    await _setMarkerSelected(place, true);

    _flyTo(place.position);
  }

  Future<void> _closePlaceDetail() async {
    final place = _selectedPlace;

    // The Explore sheet is torn down while the detail view is up, so a fresh one comes back at
    // initialChildSize. Reset the tracked extent to match, otherwise the map buttons stay parked
    // wherever the sheet happened to be when the user tapped a place - DraggableScrollableSheet
    // does not emit a notification just for being built.
    _sheetExtent.value = _kSheetRestExtent;

    setState(() {
      _showPlaceDetail = false;
      _selectedPlace = null;
    });

    if (place != null) {
      await _setMarkerSelected(place, false);
    }
  }

  void _deselect() {
    if (_showPlaceDetail) {
      _closePlaceDetail();
      return;
    }

    if (_selectedPlace == null) return;

    final place = _selectedPlace!;
    setState(() => _selectedPlace = null);
    _setMarkerSelected(place, false);
  }

  void _zoomBy(double delta) {
    _mapController?.animateCamera(
      delta > 0 ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
    );
  }

  void _recenter() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_searchOrigin, 15.2),
    );
  }

  void _flyTo(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
  }

  /// The Explore Places sheet body.
  ///
  /// [contentHeight] is the sheet's height at rest, and the inner column is laid out at exactly
  /// that height no matter how far the sheet has been dragged down. That is deliberate: if the
  /// column resized with the sheet, the card row would shrink and the images would visibly squash
  /// mid-drag. Fixing the height means dragging just slides the same content out of view.
  ///
  /// [scrollController] comes from DraggableScrollableSheet and MUST be handed to a scrollable in
  /// here - that is the only channel through which drags on the sheet body reach the sheet. Without
  /// it only the sliver of background around the content would be draggable.
  Widget _buildExplorePlacesSheet(
      double contentHeight,
      ScrollController scrollController,
      ) {
    return Container(
      width: double.infinity,
      // Clip the body to the rounded top, so the content scrolls under the corners instead of
      // squaring them off while the sheet is part-way down.
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        // AlwaysScrollable so the drag is accepted even at rest, when the content fits the
        // viewport exactly and there is nothing to actually scroll.
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: contentHeight,
          // No horizontal inset here on purpose. The card row is a horizontal ListView, and a
          // ListView clips at its own edges - inset the whole column and the cards get sliced off
          // 20px in from the sheet edge while scrolling, which reads as something covering them.
          // The 20px lives on each child instead, and on the card row it is scroll padding, so
          // cards keep their resting inset but slide off the real edge.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grab handle. Coral rather than a neutral hairline: coral is this screen's
                // "you can act on this" colour - the selected pin and the active filter chips use
                // it too - so the handle reads as draggable instead of decorative.
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Explore Places',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${_places.length} nearby',
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: _isLoadingPlaces
                      ? const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  )
                      : _placesError != null
                      ? Center(
                    child: Text(
                      _placesError!,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 13,
                      ),
                    ),
                  )
                      : _places.isEmpty
                      ? const Center(
                    child: Text(
                      'No hidden places found nearby yet.',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                  )
                      : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _places.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final place = _places[i];

                      return SizedBox(
                        width: 150,
                        child: _PlaceCard(
                          place: place,
                          onTap: () {
                            _selectPlace(place);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The map is deliberately full-bleed (SafeArea top: false) so it runs under the status bar,
    // which means anything floating on top of it has to dodge the status bar itself. Status bar
    // height varies a lot across devices (punch-hole phones are roughly double a plain one), so
    // this is read at runtime rather than hard-coded.
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.cardBg,
      body: SafeArea(
        top: false,
        // DraggableScrollableSheet measures its extents against the space IT is given - this
        // Stack - not against the window. This screen sits above a bottom nav bar owned by the
        // parent shell, so MediaQuery height is bigger than what is actually available here.
        // Measuring the real box keeps the sheet content and the map buttons in step with the
        // sheet's own idea of how tall it is; using MediaQuery would lay the card row out taller
        // than the sheet and clip the bottom of every card.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final exploreSheetHeight = constraints.maxHeight * _kSheetRestExtent;

            return Stack(
              children: [
                // -----------------------------------------------------------
                // FULL-SCREEN MAP
                // -----------------------------------------------------------
                Positioned.fill(
                  child: !_mapReady
                      ? const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  )
                      : AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _searchOrigin,
                          zoom: 15.2,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          controller.setMapStyle(_lightMapStyle);
                        },
                        markers: _markers,
                        onTap: (_) => _deselect(),
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        circles: {
                          Circle(
                            circleId: const CircleId('pulse'),
                            center: _searchOrigin,
                            radius: 40 + _pulseController.value * 70,
                            fillColor: AppColors.gmapsBlue.withOpacity(
                              (1 - _pulseController.value) * 0.25,
                            ),
                            strokeWidth: 0,
                          ),
                        },
                      );
                    },
                  ),
                ),

                // -----------------------------------------------------------
                // TOP MAP GRADIENT
                // -----------------------------------------------------------
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 130,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Search bar
                //
                // Presentational only for now - _SearchBar renders a static pill, it has no TextField
                // and no tap handler. Wire it up before demoing "search" as a feature.
                Positioned(
                  top: topInset + 10,
                  left: 14,
                  right: 14,
                  child: const _SearchBar(),
                ),

                // Filter chips
                //
                // Sits directly under the search bar: topInset + 10 (bar top) + 46 (bar height) + 8 gap.
                //
                // Stretched to the full width (left/right 0) with the 14px inset moved INSIDE the list as
                // padding. A horizontal ListView clips at its own edges, so with left/right 14 the chips
                // were being sliced off 14px in from the screen edge while scrolling - which reads as
                // something sitting on top of them rather than as a scrolling row. Padding inside the
                // viewport keeps the same resting inset but lets chips slide off the real screen edge.
                if (!_showPlaceDetail)
                  Positioned(
                    top: topInset + 64,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final f = _filters[i];
                          final isRadius = f.key == _radiusChipKey;
                          final selected =
                              isRadius || _selectedTypes.contains(f.key);

                          return _FilterChip(
                            data: f,
                            selected: selected,
                            onTap: () {
                              if (isRadius) {
                                _toggleRadius();
                              } else {
                                _toggleType(f.key);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),

                // Updating pill
                if (_mapReady && _isLoadingPlaces && !_showPlaceDetail)
                  Positioned(
                    top: 108,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Updating places...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // -----------------------------------------------------------
                // MAP CONTROLS
                // Move them above the Explore sheet when the detail sheet is
                // not open. When detail is open, they can sit on the map.
                // -----------------------------------------------------------
                // Rebuilt on every frame of a sheet drag, which is why only these two buttons live
                // inside the builder - see _sheetExtent for why this is not a setState.
                ValueListenableBuilder<double>(
                  valueListenable: _sheetExtent,
                  builder: (context, extent, _) {
                    final sheetTop =
                        _showPlaceDetail ? 0.0 : extent * constraints.maxHeight;
                    return Stack(
                      children: [
                        Positioned(
                          right: 12,
                          bottom: sheetTop + 84,
                          child: _ZoomControls(
                            onZoomIn: () => _zoomBy(1),
                            onZoomOut: () => _zoomBy(-1),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: sheetTop + 16,
                          child: _RoundIconButton(
                            icon: Icons.my_location,
                            onTap: _recenter,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // -----------------------------------------------------------
                // NORMAL EXPLORE PLACES SHEET
                // Hidden completely once a place is selected.
                // -----------------------------------------------------------
                if (!_showPlaceDetail)
                  NotificationListener<DraggableScrollableNotification>(
                    onNotification: (notification) {
                      _sheetExtent.value = notification.extent;
                      // false: this is only being observed, other listeners still want it.
                      return false;
                    },
                    child: DraggableScrollableSheet(
                      initialChildSize: _kSheetRestExtent,
                      // max == initial, so the sheet can only be pulled DOWN. See the constants.
                      maxChildSize: _kSheetRestExtent,
                      minChildSize: _kSheetCollapsedExtent,
                      // Settle on one of the two resting positions when released, instead of being
                      // left halfway - a sheet parked at 30% just hides the map badly.
                      snap: true,
                      builder: (context, scrollController) =>
                          _buildExplorePlacesSheet(exploreSheetHeight, scrollController),
                    ),
                  ),

                // -----------------------------------------------------------
                // PLACE DETAIL SHEET
                // The PlaceDetailUI owns the DraggableScrollableSheet and can
                // expand over the full map.
                // -----------------------------------------------------------
                if (_showPlaceDetail && _selectedPlace != null)
                  Positioned.fill(
                    child: PlaceDetailUI(
                      place: _selectedPlace!,
                      onClose: _closePlaceDetail,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// SEARCH BAR
// =============================================================================
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, size: 20, color: AppColors.textGrey),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Search hidden places',
              style: TextStyle(fontSize: 14, color: AppColors.textGrey),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.coral,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FILTER CHIP
// =============================================================================
class _FilterChipData {
  final String key;
  final String label;
  final IconData icon;
  const _FilterChipData(this.key, this.label, this.icon);
}

class _FilterChip extends StatelessWidget {
  final _FilterChipData data;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.coral : AppColors.chipBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data.icon,
              size: 14,
              color: selected ? Colors.white : AppColors.textDark,
            ),
            const SizedBox(width: 6),
            Text(
              data.label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ZOOM CONTROLS
// =============================================================================
class _ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomControls({required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onZoomIn,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.add, size: 20, color: AppColors.textDark),
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          InkWell(
            onTap: onZoomOut,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.remove, size: 20, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 20, color: AppColors.gmapsBlue),
        ),
      ),
    );
  }
}

// =============================================================================
// MINI PLACE CARD
// =============================================================================
class _MiniPlaceCard extends StatelessWidget {
  final PlaceData place;
  final VoidCallback onTap;

  const _MiniPlaceCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                place.imageUrl,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _PhotoPlaceholder(icon: place.icon, size: 54),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 13,
                        color: Color(0xFFF2B33D),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${place.rating}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${place.category}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PLACE CARD (bottom sheet)
// =============================================================================
class _PlaceCard extends StatelessWidget {
  final PlaceData place;
  final VoidCallback onTap;

  const _PlaceCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Guard on empty BEFORE constructing Image.network. An empty URL would still be a
                  // real (failing) image request per card, and errorBuilder would paper over it - so
                  // a list of photo-less places would quietly fire twenty pointless requests.
                  if (place.imageUrl.isEmpty)
                    _PhotoPlaceholder(icon: place.icon)
                  else
                    Image.network(
                      place.imageUrl,
                      fit: BoxFit.cover,
                      // Hold the placeholder while the bytes arrive instead of flashing empty space.
                      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                          wasSynchronouslyLoaded || frame != null
                              ? child
                              : _PhotoPlaceholder(icon: place.icon),
                      errorBuilder: (_, __, ___) =>
                          _PhotoPlaceholder(icon: place.icon),
                    ),

                  // Attribution sits on the image itself so it can never be separated from it - see
                  // PlaceData.photoAttribution. Gradient rather than a solid chip: the credit has to
                  // be legible over an unknown photo without becoming the loudest thing on the card.
                  if (place.imageUrl.isNotEmpty && place.photoAttribution != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          place.photoAttribution!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 11,
                            color: Color(0xFFF2B33D),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${place.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            place.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Text(
            place.category,
            style: const TextStyle(fontSize: 11, color: AppColors.coral),
          ),
        ],
      ),
    );
  }
}

/// Stand-in for a place photo - used until Places photos are wired up on the backend, and whenever
/// a photo URL fails to load. A neutral tile with the place's own glyph, rather than a solid block
/// of colour: with pins unified, a photo-less list should stay just as calm as the map.
class _PhotoPlaceholder extends StatelessWidget {
  final IconData icon;
  final double? size;

  const _PhotoPlaceholder({required this.icon, this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppColors.hairline,
      alignment: Alignment.center,
      child: Icon(icon, size: (size ?? 54) * 0.4, color: AppColors.pin),
    );
  }
}