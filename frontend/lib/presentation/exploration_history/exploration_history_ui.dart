import 'package:flutter/material.dart';

/// Exploration History — "History" tab content for the Exploration
/// Feature screen. Shows visited places filtered by category, same
/// chip + list pattern as the Favourite Place screen.
/// Place data is placeholder/mock for now — swap for real data once the
/// Exploration History service/repository is wired up.

const _accentColor = Color(0xFFF15A29);

class VisitedPlace {
  final String id;
  final String name;
  final String location;
  final String lastVisit;
  final String category;

  const VisitedPlace({
    required this.id,
    required this.name,
    required this.location,
    required this.lastVisit,
    required this.category,
  });
}

class ExplorationHistoryUi extends StatefulWidget {
  const ExplorationHistoryUi({super.key});

  @override
  State<ExplorationHistoryUi> createState() => _ExplorationHistoryUiState();
}

class _ExplorationHistoryUiState extends State<ExplorationHistoryUi> {
  static const _categories = ['Restaurant', 'Cafe', 'Bar', 'Nature', 'Viewpoint', 'Cultural', 'Market', 'Shopping'];
  String _selectedCategory = 'Restaurant';

  // Placeholder — replace with real visited-place data from the backend
  // once the Exploration History service is wired up.
  final List<VisitedPlace> _places = const [
    VisitedPlace(id: '1', name: 'TARUMT Arena', location: 'Malaysia, Selangor, Puchong', lastVisit: '08/01/2026', category: 'Restaurant'),
    VisitedPlace(id: '2', name: 'Last Tesco', location: 'Malaysia, Selangor, Bintang', lastVisit: '06/12/2025', category: 'Restaurant'),
    VisitedPlace(id: '3', name: 'Jurusan Park', location: 'Malaysia, KL', lastVisit: '31/11/2025', category: 'Restaurant'),
    VisitedPlace(id: '4', name: 'Bu Zhi Dao', location: 'Malaysia, Selangor, Prima', lastVisit: '09/09/2025', category: 'Restaurant'),
  ];

  List<VisitedPlace> get _filteredPlaces =>
      _places.where((p) => p.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final places = _filteredPlaces;

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
          child: places.isEmpty
              ? Center(
            child: Text(
              'No visited places in this category yet.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: places.length,
            itemBuilder: (context, index) => _VisitedPlaceCard(place: places[index]),
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

class _VisitedPlaceCard extends StatelessWidget {
  final VisitedPlace place;

  const _VisitedPlaceCard({required this.place});

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
                Text(place.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(place.location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text('Last visit at ${place.lastVisit}', style: const TextStyle(fontSize: 12, color: _accentColor)),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () {
                    // TODO: navigate to Place Details
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