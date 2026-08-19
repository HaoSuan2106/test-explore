import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// =============================================================================
// COLORS — closer to Google Maps' real palette (not the flat cream mock)
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

// A little cluster of spots around a shared center point (fictional coords,
// close together so they all fit on screen at a walking-distance zoom).
const _center = LatLng(3.1390, 101.6869); // Kuala Lumpur-ish, adjust freely

final _places = <PlaceData>[
  PlaceData(
    title: 'Mantap Café',
    category: 'Restaurant',
    imageUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=400&q=60',
    icon: Icons.local_cafe,
    pinColor: AppColors.pinYellow,
    position: const LatLng(3.1420, 101.6845),
    rating: 4.6,
  ),
  PlaceData(
    title: 'RiNG Café',
    category: 'Restaurant',
    imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&q=60',
    icon: Icons.restaurant,
    pinColor: AppColors.pinGrey,
    position: const LatLng(3.1405, 101.6892),
    rating: 4.3,
  ),
  PlaceData(
    title: 'Teluk Damai',
    category: 'Nature',
    imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&q=60',
    icon: Icons.terrain,
    pinColor: AppColors.pinGrey,
    position: const LatLng(3.1368, 101.6820),
    rating: 4.8,
  ),
  PlaceData(
    title: 'Ocean Flame Seafood',
    category: 'Restaurant',
    imageUrl: 'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=400&q=60',
    icon: Icons.set_meal,
    pinColor: AppColors.pinGrey,
    position: const LatLng(3.1355, 101.6900),
    rating: 4.1,
  ),
  PlaceData(
    title: 'Old Brick Market',
    category: 'Shopping',
    imageUrl: 'https://images.unsplash.com/photo-1601599963565-b7f49deb2fac?w=400&q=60',
    icon: Icons.shopping_bag,
    pinColor: AppColors.pinGrey,
    position: const LatLng(3.1348, 101.6838),
    rating: 4.0,
  ),
];

// =============================================================================
// SCREEN
// =============================================================================
class HiddenPlaceDiscoveryUI extends StatefulWidget {
  const HiddenPlaceDiscoveryUI({super.key});

  @override
  State<HiddenPlaceDiscoveryUI> createState() => _HiddenPlaceDiscoveryUIState();
}

class _HiddenPlaceDiscoveryUIState extends State<HiddenPlaceDiscoveryUI> {
  String _selectedFilter = 'Radius';
  int _navIndex = 0;
  PlaceData? _selectedPlace;

  final MapController _mapController = MapController();

  final List<_FilterChipData> _filters = const [
    _FilterChipData('Radius', Icons.radar),
    _FilterChipData('Nature', Icons.eco),
    _FilterChipData('Restaurant', Icons.restaurant),
    _FilterChipData('Viewpoint', Icons.landscape),
    _FilterChipData('More', Icons.tune),
  ];

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _recenter() {
    _mapController.move(_center, 15.2);
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
                  // Real map tiles
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 15.2,
                      minZoom: 4,
                      maxZoom: 19,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (_, __) => setState(() => _selectedPlace = null),
                    ),
                    children: [
                      // CartoDB "Positron" — a clean light basemap, closer
                      // in spirit to the cream/soft palette of the mock than
                      // stock OSM tiles.
                      TileLayer(
                        urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.example.explore_my',
                      ),
                      // Place markers
                      MarkerLayer(
                        markers: [
                          for (final place in _places)
                            Marker(
                              point: place.position,
                              width: 46,
                              height: 56,
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedPlace = place),
                                child: _MapPinTeardrop(
                                  icon: place.icon,
                                  color: place.pinColor,
                                  selected: _selectedPlace == place,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // "You are here" blue dot
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _center,
                            width: 40,
                            height: 40,
                            child: const _UserLocationDot(),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        alignment: AttributionAlignment.bottomLeft,
                        attributions: [
                          TextSourceAttribution(
                            '© OpenStreetMap contributors, © CARTO',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Soft gradient so the search bar/chips stay legible
                  // over busy map tiles.
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
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: _SearchBar(),
                  ),

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
                          final selected = f.label == _selectedFilter;
                          return _FilterChip(
                            data: f,
                            selected: selected,
                            onTap: () => setState(() => _selectedFilter = f.label),
                          );
                        },
                      ),
                    ),
                  ),

                  // Zoom controls (Google-Maps-style stacked +/-)
                  Positioned(
                    right: 12,
                    bottom: 84,
                    child: _ZoomControls(
                      onZoomIn: () => _zoomBy(1),
                      onZoomOut: () => _zoomBy(-1),
                    ),
                  ),

                  // Recenter (my-location) button
                  Positioned(
                    right: 12,
                    bottom: 16,
                    child: _RoundIconButton(
                      icon: Icons.my_location,
                      onTap: _recenter,
                    ),
                  ),

                  // Selected place preview card (floats above the sheet)
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
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
                  ],
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
                        Text(
                          '${_places.length} nearby',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
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
                                setState(() => _selectedPlace = place);
                                _mapController.move(place.position, 16);
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

            _BottomNav(
              currentIndex: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
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
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3)),
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
  final String label;
  final IconData icon;
  const _FilterChipData(this.label, this.icon);
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2)),
          ],
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
// MAP PIN (teardrop, Google-Maps style)
// =============================================================================
class _MapPinTeardrop extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;

  const _MapPinTeardrop({required this.icon, required this.color, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final scale = selected ? 1.15 : 1.0;
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 40,
        height: 50,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(Icons.location_on, size: 44, color: color, shadows: const [
              Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ]),
            Positioned(
              top: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// USER LOCATION DOT (with pulsing halo, like Google Maps' blue dot)
// =============================================================================
class _UserLocationDot extends StatefulWidget {
  const _UserLocationDot();

  @override
  State<_UserLocationDot> createState() => _UserLocationDotState();
}

class _UserLocationDotState extends State<_UserLocationDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40 * (0.4 + t * 0.6),
                height: 40 * (0.4 + t * 0.6),
                decoration: BoxDecoration(
                  color: AppColors.gmapsBlue.withOpacity((1 - t) * 0.35),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.gmapsBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
            ],
          ),
        );
      },
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
// MINI PLACE CARD (shown when a pin is tapped)
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
            child: Image.network(place.imageUrl, width: 54, height: 54, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 54, height: 54, color: place.pinColor)),
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
// PLACE CARD (bottom sheet, horizontal scroll)
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

// =============================================================================
// BOTTOM NAV
// =============================================================================
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.explore_outlined, Icons.explore, 'Explore'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Community'),
    (Icons.add_box_outlined, Icons.add_box, 'Post'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final (iconOutline, iconFilled, label) = _items[i];
          final selected = i == currentIndex;
          final color = selected ? AppColors.coral : AppColors.textGrey;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? iconFilled : iconOutline, color: color, size: 22),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }),
      ),
    );
  }
}