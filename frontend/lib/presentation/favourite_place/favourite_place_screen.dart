import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/foot_tracker/exploration_model.dart';
import '../../providers/foot_tracker/favourite_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart' show PlaceData;
import '../place_details/place_detail_map_screen.dart';

/// Favourite Place — Favourite List screen
/// Matches UC301 A5 (Manage Favourite Place) / UC103 A4.
/// Category filtering and multi-select delete are UI-only state, kept
/// local to this widget. The actual place data now comes from
/// FavouriteProvider instead of being hardcoded here.

const _accentColor = Color(0xFFF15A29);
const _dangerColor = Color(0xFFB03A2E);

class FavouritePlaceScreen extends StatefulWidget {
  const FavouritePlaceScreen({super.key});

  @override
  State<FavouritePlaceScreen> createState() => _FavouritePlaceScreenState();
}

PlaceData _favouriteToPlaceData(FavouritePlace place) {
  return PlaceData(
    placeId: place.placeId,
    title: place.name,
    category: place.category,
    primaryType: place.category,
    imageUrl: '',
    icon: Icons.place,
    position: LatLng(place.latitude, place.longitude),
    rating: 0.0,
    ratingCount: 0,
    priceLevel: null,
    businessStatus: 'UNKNOWN',
    photoAttribution: null,
    address: place.location,
    phoneNumber: null,
    websiteUri: null,
    googleMapsUri: null,
    photosJson: null,
    regularOpeningHoursJson: null,
  );
}

class _FavouritePlaceScreenState extends State<FavouritePlaceScreen> {
  static const _categories = ['All','Restaurant', 'Cafe', 'Bar', 'Nature', 'Viewpoint', 'Cultural', 'Market', 'Shopping'];
  String _selectedCategory = 'All';

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    context.read<FavouriteProvider>().loadPlaces();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ConfirmDialog(
        title: 'Delete Selected Places?',
        message: 'This action cannot be undone. Are you sure you want to remove these from your list?',
        confirmLabel: 'Confirm',
        cancelLabel: 'Cancel',
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<FavouriteProvider>().deletePlaces(_selectedIds);

    await showDialog<void>(
      context: context,
      builder: (context) => const _InfoDialog(
        title: 'Place Removed',
        message: 'Place has been removed from your favourite list successfully.',
        confirmLabel: 'Confirm',
      ),
    );

    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FavouriteProvider>();
    final places = _selectedCategory == 'All'
        ? provider.places
        : provider.places.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              selectionMode: _selectionMode,
              onBack: () => Navigator.of(context).maybePop(),
              onDeleteTap: _toggleSelectionMode,
            ),
            _CategoryChips(
              categories: _categories,
              selected: _selectedCategory,
              onSelected: (c) => setState(() {
                _selectedCategory = c;
                _selectionMode = false;
                _selectedIds.clear();
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text('Visited Places', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (_selectionMode) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(tap a place to select it)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : places.isEmpty
                  ? _EmptyState(onExplore: () => Navigator.of(context).maybePop())
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index];
                  return _FavouritePlaceCard(
                    place: place,
                    selectionMode: _selectionMode,
                    isSelected: _selectedIds.contains(place.id),
                    onTap: _selectionMode
                        ? () => _toggleSelected(place.id)
                        : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlaceDetailMapScreen(
                            place: _favouriteToPlaceData(place),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectionMode && _selectedIds.isNotEmpty
          ? _SelectionBar(count: _selectedIds.length, onDelete: _confirmDelete)
          : null,
    );
  }
}

class _Header extends StatelessWidget {
  final bool selectionMode;
  final VoidCallback onBack;
  final VoidCallback onDeleteTap;

  const _Header({required this.selectionMode, required this.onBack, required this.onDeleteTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.arrow_back, onTap: onBack),
          Expanded(
            child: Text(
              selectionMode ? 'Select Places' : 'Favourite List',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          _CircleIconButton(
            icon: selectionMode ? Icons.close : Icons.delete_outline,
            onTap: onDeleteTap,
            isActive: selectionMode,
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _CircleIconButton({required this.icon, required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    // Using IconButton (rather than a bare InkWell) guarantees the tap
    // is registered reliably across platforms, including desktop mouse input.
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: isActive ? Colors.white : Colors.black87),
      style: IconButton.styleFrom(
        backgroundColor: isActive ? _dangerColor : Colors.grey.shade100,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
      ),
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
    // Horizontally scrollable, per the Figma prototype notes (chips can
    // extend beyond the viewport with horizontal scrolling enabled).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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

class _FavouritePlaceCard extends StatelessWidget {
  final FavouritePlace place;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;

  const _FavouritePlaceCard({
    required this.place,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _dangerColor.withOpacity(0.06) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
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
                  if (selectionMode)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? _dangerColor : Colors.white,
                          border: Border.all(color: isSelected ? _dangerColor : Colors.grey.shade400, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(place.location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Text(
                      place.hasVisited ? 'Last visit at ${place.lastVisit}' : 'Saved on ${place.lastVisit}',
                      style: const TextStyle(fontSize: 12, color: _accentColor),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: selectionMode
                          ? null
                          : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PlaceDetailMapScreen(
                              place: _favouriteToPlaceData(place),
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
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onDelete;

  const _SelectionBar({required this.count, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$count items selected', style: const TextStyle(fontWeight: FontWeight.w600)),
            ElevatedButton(
              onPressed: onDelete,
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Delete Selected', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onExplore;

  const _EmptyState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You have no added favourite places.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Some favourite hidden place to this favourite list',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onExplore,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Explore', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(cancelLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const _InfoDialog({required this.title, required this.message, required this.confirmLabel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}