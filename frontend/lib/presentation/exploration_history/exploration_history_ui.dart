import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/foot_tracker/visit_log_model.dart';
import '../../providers/foot_tracker/navigation_provider.dart';
import '../../models/foot_tracker/exploration_model.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart' show PlaceData;
import '../place_details/place_detail_map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const _accentColor = Color(0xFFF15A29);

class ExplorationHistoryUi extends StatefulWidget {
  const ExplorationHistoryUi({super.key});

  @override
  State<ExplorationHistoryUi> createState() => _ExplorationHistoryUiState();
}

class _ExplorationHistoryUiState extends State<ExplorationHistoryUi> {
  static const _categories = ['All', 'Restaurant', 'Cafe', 'Bar', 'Nature', 'Viewpoint', 'Cultural', 'Market', 'Shopping'];
  String _selectedCategory = 'All';

  bool _isLoading = true;
  String? _errorMessage;
  List<VisitLog> _visits = [];

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final visits = await context.read<NavigationProvider>().getVisits();
      if (!mounted) return;
      setState(() {
        _visits = visits;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load exploration history.';
        _isLoading = false;
      });
    }
  }

  List<VisitLog> get _filteredVisits =>
      _selectedCategory == 'All' ? _visits : _visits.where((v) => v.primaryType == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadVisits, child: const Text('Retry')),
          ],
        ),
      );
    }

    final visits = _filteredVisits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryChips(
          categories: _categories,
          selected: _selectedCategory,
          onSelected: (c) => setState(() => _selectedCategory = c),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text('Visited Places', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: visits.isEmpty
              ? Center(
            child: Text(
              'No visited places in this category yet.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadVisits,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: visits.length,
              itemBuilder: (context, index) => _VisitedPlaceCard(visit: visits[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryChips({required this.categories, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          for (final c in categories) ...[
            _CategoryChip(label: c, isSelected: c == selected, onTap: () => onSelected(c)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _accentColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

PlaceData _visitToPlaceData(VisitLog visit) {
  final rawType = visit.primaryType ?? 'unknown';
  return PlaceData(
    placeId: visit.placeId!,
    title: visit.title,
    category: FavouritePlace.mapToUiCategory(rawType),
    primaryType: rawType,
    imageUrl: '',
    icon: Icons.place,
    position: LatLng(visit.latitude!, visit.longitude!),
    rating: 0.0,
    ratingCount: 0,
    priceLevel: null,
    businessStatus: 'UNKNOWN',
    photoAttribution: null,
    address: visit.address,
    phoneNumber: null,
    websiteUri: null,
    googleMapsUri: null,
    photosJson: null,
    regularOpeningHoursJson: null,
  );
}

class _VisitedPlaceCard extends StatelessWidget {
  final VisitLog visit;

  const _VisitedPlaceCard({required this.visit});

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              color: Colors.grey.shade200,
              child: Icon(Icons.photo, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visit.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                if (visit.address != null)
                  Text(visit.address!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text('Last visit at ${_formatDate(visit.endedAt)}', style: const TextStyle(fontSize: 12, color: _accentColor)),
                const SizedBox(height: 6),
                if (visit.placeId != null && visit.latitude != null && visit.longitude != null)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlaceDetailMapScreen(
                            place: _visitToPlaceData(visit),
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('View More', style: TextStyle(fontSize: 11, color: Colors.black87)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}