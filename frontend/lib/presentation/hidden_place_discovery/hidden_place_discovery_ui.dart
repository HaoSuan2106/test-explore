import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../api_communication/location_service/device_location_service.dart';
import '../../models/hidden_place/hidden_place_model.dart';
import '../../providers/hidden_place/hidden_place_provider.dart';

// =============================================================================
// COLORS
// =============================================================================
class AppColors {
  static const coral = Color(0xFFFF6B4A);
  static const coralLight = Color(0xFFFFE4DB);

  static const pinGrey = Color(0xFF5F6368);
  static const pinYellow = Color(0xFFF2B33D);

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
  final String title;
  final String category;
  final String imageUrl;
  final IconData icon;
  final Color pinColor;
  final LatLng position;
  final double rating;

  const PlaceData({
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.icon,
    required this.pinColor,
    required this.position,
    required this.rating,
  });
}

// Fallback origin used until the device's real GPS position comes back (or if location
// permission is denied / services are off) - keeps the map centered somewhere sensible
// instead of the middle of the ocean at (0, 0).
const _center = LatLng(3.1390, 101.6869); // Kuala Lumpur-ish, adjust freely

// The only two search radii the user can pick between - must match the backend's
// [AllowedValues(5_000, 10_000)] on DiscoverHiddenPlaceRequestDto.RadiusMeters. Keeping this a
// closed set (rather than a free-form slider) means every search this screen makes lands on one
// of the two radii the backend's grid cache is actually tuned for - see SearchGridPlanner.
const List<int> _radiusOptionsMeters = [5000, 10000];

/// Picks a marker icon + color for a place based on its Google Places primary type.
/// Places API doesn't tell us "nice icon to use", so this is our own mapping.
({IconData icon, Color color}) _styleForType(String primaryType) {
  switch (primaryType) {
    case 'restaurant':
    case 'meal_takeaway':
    case 'meal_delivery':
      return (icon: Icons.restaurant, color: AppColors.pinGrey);
    case 'cafe':
    case 'bakery':
      return (icon: Icons.local_cafe, color: AppColors.pinYellow);
    case 'tourist_attraction':
    case 'park':
    case 'natural_feature':
      return (icon: Icons.terrain, color: AppColors.pinGrey);
    case 'museum':
      return (icon: Icons.museum, color: AppColors.pinGrey);
    case 'shopping_mall':
    case 'store':
      return (icon: Icons.shopping_bag, color: AppColors.pinGrey);
    default:
      return (icon: Icons.place, color: AppColors.pinGrey);
  }
}

String _humanizeType(String primaryType) {
  final words = primaryType.split('_');
  return words.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

/// Maps a raw API result (HiddenPlaceModel) to this screen's presentation model (PlaceData).
/// Places API photos aren't wired up on the backend yet, so imageUrl is left blank and the
/// UI falls back to a solid color tile (see _PlaceCard/_MiniPlaceCard errorBuilder).
PlaceData _toPlaceData(HiddenPlaceModel place) {
  final style = _styleForType(place.primaryType);
  return PlaceData(
    title: place.name,
    category: _humanizeType(place.primaryType),
    imageUrl: '',
    icon: style.icon,
    pinColor: style.color,
    position: LatLng(place.latitude, place.longitude),
    rating: place.rating ?? 0.0,
  );
}

// =============================================================================
// MARKER BITMAP GENERATOR
// Google Maps native markers can't embed arbitrary widgets, so we rasterize
// a teardrop pin (icon + color) into a PNG and hand it to BitmapDescriptor.
// =============================================================================
class _MarkerFactory {
  static Future<BitmapDescriptor> pin({
    required IconData icon,
    required Color color,
    bool selected = false,
  }) async {
    final double size = selected ? 92 : 76;
    final double tailExtra = 24;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size + tailExtra));

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
    final body = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
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
        color: color,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), (size + tailExtra).toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> userDot() async {
    const double size = 46;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final center = const Offset(size / 2, size / 2);

    canvas.drawCircle(center, 20, Paint()..color = Colors.white);
    canvas.drawCircle(center, 16, Paint()..color = AppColors.gmapsBlue);

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
  // 'radius' is the internal key for the radius-toggle chip (its label changes at runtime to show
  // "5km"/"10km", so we can't compare against the label like the other, static chips do).
  String _selectedFilter = 'radius';
  int _navIndex = 0;
  PlaceData? _selectedPlace;
  bool _mapReady = false;

  List<PlaceData> _places = [];
  bool _isLoadingPlaces = true;
  String? _placesError;

  // Which of _radiusOptionsMeters is currently active. Defaults to the smaller/first option.
  int _radiusMeters = _radiusOptionsMeters.first;

  // Starts as the fallback constant; _loadPlaces() overwrites it with the device's
  // real GPS position when available, before the map/markers are ever built.
  LatLng _searchOrigin = _center;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  BitmapDescriptor? _userIcon;

  // Marker bitmaps only depend on (icon, color, selected) - not on which specific place they're for -
  // and there are only a handful of distinct combinations (one per _styleForType category). Caching
  // them means switching radius (or re-selecting a place) reuses already-rasterized bitmaps instead of
  // redrawing a canvas + encoding a PNG for every single place on every fetch, which was the main
  // reason the map felt slow (1-2s) whenever the radius chip was toggled.
  final Map<String, BitmapDescriptor> _pinIconCache = {};
  Future<BitmapDescriptor>? _userIconFuture;

  Future<BitmapDescriptor> _pinIconFor(PlaceData place, {required bool selected}) async {
    final key = '${place.icon.codePoint}_${place.pinColor.value}_$selected';
    final cached = _pinIconCache[key];
    if (cached != null) return cached;
    final icon = await _MarkerFactory.pin(icon: place.icon, color: place.pinColor, selected: selected);
    _pinIconCache[key] = icon;
    return icon;
  }

  late final AnimationController _pulseController =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  // Built fresh on every build() rather than kept as a static const list, since the first chip's
  // label needs to reflect the currently-selected radius (e.g. "5km radius").
  List<_FilterChipData> get _filters => [
        _FilterChipData('radius', '${_radiusMeters ~/ 1000}km radius', Icons.radar),
        const _FilterChipData('nature', 'Nature', Icons.eco),
        const _FilterChipData('restaurant', 'Restaurant', Icons.restaurant),
        const _FilterChipData('viewpoint', 'Viewpoint', Icons.landscape),
        const _FilterChipData('more', 'More', Icons.tune),
      ];

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Gets the device's real GPS position (falling back to _center if location is
  /// unavailable/denied), then fetches nearby hidden-gem places from the backend
  /// (Google Places API + the hidden-score algorithm) centered on that point, and
  /// rebuilds the map pins.
  Future<void> _loadPlaces() async {
    final position = await const DeviceLocationService().getCurrentPosition();
    if (mounted && position != null) {
      setState(() => _searchOrigin = LatLng(position.latitude, position.longitude));
    }
    await _fetchPlaces();
  }

  /// Re-fetches places for the current _searchOrigin + _radiusMeters, without touching GPS -
  /// used when the user just switches the radius chip and doesn't need a fresh location fix.
  Future<void> _fetchPlaces() async {
    if (mounted) {
      setState(() => _isLoadingPlaces = true);
    }

    final provider = context.read<HiddenPlaceProvider>();
    await provider.loadNearby(
      latitude: _searchOrigin.latitude,
      longitude: _searchOrigin.longitude,
      radiusMeters: _radiusMeters,
    );
    if (!mounted) return;
    setState(() {
      _places = provider.places.map(_toPlaceData).toList();
      _isLoadingPlaces = false;
      _placesError = provider.errorMessage;
    });
    await _buildMarkers();
  }

  /// Cycles between the allowed radius options (currently just 5km <-> 10km) and re-fetches.
  void _toggleRadius() {
    final currentIndex = _radiusOptionsMeters.indexOf(_radiusMeters);
    final nextIndex = (currentIndex + 1) % _radiusOptionsMeters.length;
    setState(() => _radiusMeters = _radiusOptionsMeters[nextIndex]);
    _fetchPlaces();
  }

  Future<void> _buildMarkers() async {
    // The user-location dot never changes, so only ever build it once and reuse the same Future for
    // every subsequent call (e.g. every radius toggle) instead of re-rasterizing it each time.
    final userIcon = await (_userIconFuture ??= _MarkerFactory.userDot());

    // Build every place's marker bitmap concurrently (and via the cache in _pinIconFor) instead of
    // awaiting them one at a time - with ~10-20 places that sequential loop was the main source of the
    // 1-2s pause whenever the radius chip was switched.
    final icons = await Future.wait(_places.map((place) => _pinIconFor(place, selected: false)));

    final built = <Marker>{
      for (var i = 0; i < _places.length; i++)
        Marker(
          markerId: MarkerId(_places[i].title),
          position: _places[i].position,
          icon: icons[i],
          anchor: const Offset(0.5, 1.0),
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

  /// Rebuilds one place's marker at the given size (selected = big, unselected = normal) and swaps
  /// it into _markers. Shared by _selectPlace/_deselect so a marker always gets shrunk back down
  /// the same way it got enlarged, instead of each call site duplicating the marker-rebuild logic.
  Future<void> _setMarkerSelected(PlaceData place, bool selected) async {
    final icon = await _pinIconFor(place, selected: selected);
    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == place.title);
      _markers.add(
        Marker(
          markerId: MarkerId(place.title),
          position: place.position,
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          onTap: () => _selectPlace(place),
        ),
      );
    });
  }

  Future<void> _selectPlace(PlaceData place) async {
    final previouslySelected = _selectedPlace;
    setState(() => _selectedPlace = place);

    // Shrink whatever was selected before (if it's a different place) back down to normal size -
    // otherwise it would stay enlarged forever once you tap a second marker.
    if (previouslySelected != null && previouslySelected.title != place.title) {
      await _setMarkerSelected(previouslySelected, false);
    }

    await _setMarkerSelected(place, true);
  }

  void _deselect() {
    if (_selectedPlace == null) return;
    final place = _selectedPlace!;
    setState(() => _selectedPlace = null);
    _setMarkerSelected(place, false);
  }

  void _zoomBy(double delta) {
    _mapController?.animateCamera(delta > 0 ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut());
  }

  void _recenter() {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_searchOrigin, 15.2));
  }

  void _flyTo(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // -----------------------------------------------------------
            // MAP AREA
            // -----------------------------------------------------------
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  if (!_mapReady)
                    const Center(child: CircularProgressIndicator(color: AppColors.coral))
                  else
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return GoogleMap(
                          initialCameraPosition: CameraPosition(target: _searchOrigin, zoom: 15.2),
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
                              fillColor: AppColors.gmapsBlue.withOpacity((1 - _pulseController.value) * 0.25),
                              strokeWidth: 0,
                            ),
                          },
                        );
                      },
                    ),

                  // Gradient so the search bar/chips stay legible.
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
                            colors: [Colors.black.withOpacity(0.18), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Search bar
                  const Positioned(top: 14, left: 14, right: 14, child: _SearchBar()),

                  // Filter chips
                  Positioned(
                    top: 68,
                    left: 14,
                    right: 14,
                    child: SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final f = _filters[i];
                          final selected = f.key == _selectedFilter;
                          return _FilterChip(
                            data: f,
                            selected: selected,
                            onTap: () {
                              setState(() => _selectedFilter = f.key);
                              if (f.key == 'radius') {
                                _toggleRadius();
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Small "updating..." pill shown while re-fetching over an already-visible map (e.g.
                  // after toggling the radius chip) - the fetch + marker rebuild can take a second or
                  // two, and without this the map just sits there looking frozen/unresponsive in the
                  // meantime. Only shown after the initial load (_mapReady) - the first load already has
                  // its own full-screen spinner instead.
                  if (_mapReady && _isLoadingPlaces)
                    Positioned(
                      top: 108,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: 8),
                              Text('Updating places...',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Zoom controls
                  Positioned(
                    right: 12,
                    bottom: 84,
                    child: _ZoomControls(
                      onZoomIn: () => _zoomBy(1),
                      onZoomOut: () => _zoomBy(-1),
                    ),
                  ),

                  // Recenter
                  Positioned(
                    right: 12,
                    bottom: 16,
                    child: _RoundIconButton(icon: Icons.my_location, onTap: _recenter),
                  ),

                  // Selected place preview
                  if (_selectedPlace != null)
                    Positioned(
                      left: 14,
                      right: 76,
                      bottom: 16,
                      child: _MiniPlaceCard(place: _selectedPlace!),
                    ),
                ],
              ),
            ),

            // -----------------------------------------------------------
            // EXPLORE PLACES SHEET
            // -----------------------------------------------------------
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
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
                        Text('${_places.length} nearby',
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      ],
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
                                    style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
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
                                              _flyTo(place.position);
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
          ],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, size: 20, color: AppColors.textGrey),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Search hidden places', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
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

  const _FilterChip({required this.data, required this.selected, required this.onTap});

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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 14, color: selected ? Colors.white : AppColors.textDark),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
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
  const _MiniPlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
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
              errorBuilder: (_, __, ___) => Container(width: 54, height: 54, color: place.pinColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(place.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star, size: 13, color: Color(0xFFF2B33D)),
                    const SizedBox(width: 2),
                    Text('${place.rating}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    const SizedBox(width: 6),
                    Text('· ${place.category}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                  Image.network(
                    place.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: place.pinColor),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 11, color: Color(0xFFF2B33D)),
                          const SizedBox(width: 2),
                          Text('${place.rating}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(place.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text(place.category, style: const TextStyle(fontSize: 11, color: AppColors.coral)),
        ],
      ),
    );
  }
}
