import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../providers/foot_tracker/exploration_map_provider.dart';


class _District {
  final String name;
  final int visitedCount;
  final List<List<LatLng>> polygonPieces;

  const _District({
    required this.name,
    required this.visitedCount,
    required this.polygonPieces,
  });
}

Future<List<_District>> _loadDistrictsFromAsset(Map<String, int> visitCounts) async {
  final raw = await rootBundle.loadString('assets/geojson/malaysia.district.geojson');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final features = data['features'] as List<dynamic>;

  return features.map((f) {
    final props = f['properties'] as Map<String, dynamic>;
    final geometry = f['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>; // MultiPolygon

    final pieces = <List<LatLng>>[];
    for (final polygon in coordinates) {
      final exteriorRing = (polygon as List<dynamic>).first as List<dynamic>;
      pieces.add(exteriorRing.map((point) {
        final p = point as List<dynamic>;
        return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
      }).toList());
    }

    final name = props['name'] as String;
    return _District(
      name: name,
      visitedCount: visitCounts[name] ?? 0,
      polygonPieces: pieces,
    );
  }).toList();
}

class PersonalExplorationMapUi extends StatefulWidget {
  const PersonalExplorationMapUi({super.key});

  @override
  State<PersonalExplorationMapUi> createState() => _PersonalExplorationMapUiState();
}

class _PersonalExplorationMapUiState extends State<PersonalExplorationMapUi> {
  GoogleMapController? _mapController;
  static const LatLng _initialCenter = LatLng(3.1945, 101.6965);

  List<_District> _districts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = context.read<ExplorationMapProvider>();
      await provider.loadExplorationMap();
      if (provider.errorMessage != null) {
        throw Exception(provider.errorMessage);
      }

      final districts = await _loadDistrictsFromAsset(provider.visitCounts);
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Exploration map load failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load your exploration map.';
        _isLoading = false;
      });
    }
  }

  static Color? _colorForVisitCount(int count) {
    if (count == 0) return null;
    if (count < 10) return const Color(0xFFF9EDB2);
    if (count < 25) return const Color(0xFFF15A29);
    return const Color(0xFFB33418);
  }

  Set<Polygon> get _polygons => _districts.expand((district) {
    final color = _colorForVisitCount(district.visitedCount);
    if (color == null) return const Iterable<Polygon>.empty();
    return district.polygonPieces.asMap().entries.map((entry) {
      return Polygon(
        polygonId: PolygonId('${district.name}_${entry.key}'),
        points: entry.value,
        fillColor: color.withOpacity(0.45),
        strokeColor: color,
        strokeWidth: 2,
      );
    });
  }).toSet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadData, child: const Text('Retry')),
                  ],
                ),
              )
                  : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _initialCenter,
                      zoom: 8,
                    ),
                    polygons: _polygons,
                    onMapCreated: (controller) => _mapController = controller,
                  ),
                  const Positioned(
                    left: 16,
                    bottom: 16,
                    child: _ExplorationHeatmapLegend(),
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

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
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
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _ExplorationHeatmapLegend extends StatelessWidget {
  const _ExplorationHeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendRow(color: Color(0xFFF9EDB2), label: '1–9 visits'),
          SizedBox(height: 4),
          _LegendRow(color: Color(0xFFF15A29), label: '10–24 visits'),
          SizedBox(height: 4),
          _LegendRow(color: Color(0xFFB33418), label: '25+ visits'),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}