import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Shows the user's personal exploration heatmap: districts shaded
/// according to how many verified hidden places the user has visited
/// within each one, per constraint C6.
class PersonalExplorationMapUi extends StatefulWidget {
  const PersonalExplorationMapUi({super.key});

  @override
  State<PersonalExplorationMapUi> createState() =>
      _PersonalExplorationMapUiState();
}

class _PersonalExplorationMapUiState extends State<PersonalExplorationMapUi> {
  GoogleMapController? _mapController;

  static const LatLng _initialCenter = LatLng(3.1945, 101.6965);

  // TODO: replace with the real per-district visited-hidden-place counts
  // from the backend (REQ201_3 / REQ201_4 / REQ201_5) once the Exploration
  // heatmap endpoint exists. Boundaries below are placeholder shapes.
  static final List<_District> _districts = [
    _District(
      name: 'Taman Sri Rampai',
      visitedCount: 14,
      points: const [
        LatLng(3.1945, 101.6935),
        LatLng(3.1965, 101.6945),
        LatLng(3.1975, 101.6975),
        LatLng(3.1960, 101.7000),
        LatLng(3.1930, 101.6995),
        LatLng(3.1915, 101.6965),
      ],
    ),
    _District(
      name: 'Setapak',
      visitedCount: 6,
      points: const [
        LatLng(3.1980, 101.6900),
        LatLng(3.1995, 101.6920),
        LatLng(3.1985, 101.6950),
        LatLng(3.1960, 101.6940),
        LatLng(3.1965, 101.6910),
      ],
    ),
    _District(
      name: 'Wangsa Maju',
      visitedCount: 27,
      points: const [
        LatLng(3.1900, 101.7000),
        LatLng(3.1920, 101.7020),
        LatLng(3.1905, 101.7050),
        LatLng(3.1880, 101.7035),
        LatLng(3.1885, 101.7010),
      ],
    ),
  ];

  // TODO: replace with real visited-place markers from the backend once
  // the Exploration feature's provider/API is wired up.
  static const List<_MapPlace> _places = [
    _MapPlace(name: 'Taman Sri Rampai', position: LatLng(3.1958, 101.6958)),
    _MapPlace(
      name: 'United Kepong Rooms',
      position: LatLng(3.1938, 101.6978),
    ),
  ];

  /// Implements constraint C6:
  /// 0 visits -> no colour, <10 -> light blue, <25 -> blue, else dark blue.
  static Color? _colorForVisitCount(int count) {
    if (count == 0) return null;
    if (count < 10) return const Color(0xFFBFE3F2); // light blue
    if (count < 25) return const Color(0xFF6FB8DE); // blue
    return const Color(0xFF1B4F82); // dark blue
  }

  Set<Polygon> get _polygons => _districts
      .map((district) {
    final color = _colorForVisitCount(district.visitedCount);
    if (color == null) return null;
    return Polygon(
      polygonId: PolygonId(district.name),
      points: district.points,
      fillColor: color.withOpacity(0.45),
      strokeColor: color,
      strokeWidth: 2,
    );
  })
      .whereType<Polygon>()
      .toSet();

  Set<Marker> get _markers => _places
      .map(
        (place) => Marker(
      markerId: MarkerId(place.name),
      position: place.position,
      infoWindow: InfoWindow(title: place.name),
    ),
  )
      .toSet();

  @override  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(36, 36),
              ),
            ),
            const Expanded(
              child: Text(
                'Personal Exploration Map',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black),
              ),
            ),
            const SizedBox(width: 36),
          ],
        ),
      ),
      body: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialCenter,
                zoom: 14,
              ),
              polygons: _polygons,
              markers: _markers,
              onMapCreated: (controller) => _mapController = controller,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
            const Positioned(
              top: 12,
              left: 12,
              child: _ExplorationHeatmapLegend(),
            ),
          ],
        ),
      ),
    );
  }
}

class _District {
  final String name;
  final int visitedCount;
  final List<LatLng> points;

  const _District({
    required this.name,
    required this.visitedCount,
    required this.points,
  });
}

class _MapPlace {
  final String name;
  final LatLng position;

  const _MapPlace({required this.name, required this.position});
}

/// Legend matching constraint C6's exact district-visit-count -> colour rule.
class _ExplorationHeatmapLegend extends StatelessWidget {
  const _ExplorationHeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Exploration Density',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          _LegendRow(color: Color(0xFFD9D9D9), label: '0 visits: No colour'),
          _LegendRow(
            color: Color(0xFFBFE3F2),
            label: '1-9 visits: Light Blue',
          ),
          _LegendRow(color: Color(0xFF6FB8DE), label: '10-24 visits: Blue'),
          _LegendRow(
            color: Color(0xFF1B4F82),
            label: '25+ visits: Dark Blue',
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}