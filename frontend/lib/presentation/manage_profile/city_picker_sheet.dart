import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utilities/world_cities.dart';
import '../../widgets/animated_tap_button.dart';

const Color _kPrimaryOrange = Color(0xFFFF7148);
const Color _kTitleDark = Color(0xFF101C2C);
const Color _kMuted = Color(0xFF64748B);
const Color _kInputBorder = Color(0xFFDCE3ED);
const Color _kActionBorder = Color(0xFFF3B9AE);

/// Two-step city picker: choose a country, then a city within it.
///
/// Returns the chosen [CityOption], or null if the user backed out. The
/// country step comes first so the city list is only ever one country deep —
/// a flat worldwide list has three Londons and eleven Springfields in it, and
/// no way to tell them apart.
///
/// [initialCountryName] pre-opens that country's city list, so re-editing a
/// saved "Kuala Lumpur, Malaysia" starts where the user left off.
Future<CityOption?> showCityPicker(
  BuildContext context, {
  String? initialCountryName,
}) {
  return showModalBottomSheet<CityOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CityPickerSheet(initialCountryName: initialCountryName),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({this.initialCountryName});

  final String? initialCountryName;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  List<Country> _countries = const [];
  Country? _selectedCountry;
  List<CityOption> _cities = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadCountries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // The city lists are only needed while the picker is open; the largest is
    // a few hundred kilobytes and nothing else in the app reads them.
    WorldCities.releaseCities();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    final countries = await WorldCities.countries();
    if (!mounted) return;

    final initial = widget.initialCountryName;
    Country? preselected;
    if (initial != null && initial.isNotEmpty) {
      final key = WorldCities.fold(initial);
      for (final country in countries) {
        if (country.searchKey == key) {
          preselected = country;
          break;
        }
      }
    }

    setState(() {
      _countries = countries;
      _isLoading = false;
    });

    if (preselected != null) await _openCountry(preselected);
  }

  Future<void> _openCountry(Country country) async {
    setState(() {
      _selectedCountry = country;
      _isLoading = true;
      _cities = const [];
      _searchController.clear();
    });

    final cities = await WorldCities.citiesOf(country);
    if (!mounted) return;

    setState(() {
      _cities = cities;
      _isLoading = false;
    });
  }

  void _backToCountries() {
    setState(() {
      _selectedCountry = null;
      _cities = const [];
      _searchController.clear();
    });
  }

  /// Entries whose key contains the folded query, those that *start* with it
  /// first — so typing "york" offers York before New York.
  List<T> _filter<T>(List<T> items, String Function(T) keyOf) {
    final needle = WorldCities.fold(_searchController.text.trim());
    if (needle.isEmpty) return items;

    final startsWith = <T>[];
    final contains = <T>[];
    for (final item in items) {
      final key = keyOf(item);
      if (key.startsWith(needle)) {
        startsWith.add(item);
      } else if (key.contains(needle)) {
        contains.add(item);
      }
    }
    return [...startsWith, ...contains];
  }

  @override
  Widget build(BuildContext context) {
    final country = _selectedCountry;
    final isCityStep = country != null;

    return Padding(
      // Lift the sheet above the keyboard so the list stays usable while the
      // user types.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kActionBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isCityStep) ...[
                      AnimatedTapButton(
                        onTap: _backToCountries,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.arrow_back,
                              size: 20, color: _kTitleDark),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        isCityStep ? country.name : 'Select Country',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kTitleDark,
                        ),
                      ),
                    ),
                    AnimatedTapButton(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 22, color: _kTitleDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _searchController,
                  hintText: isCityStep
                      ? 'Search cities in ${country.name}'
                      : 'Search countries',
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildList(isCityStep)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(bool isCityStep) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kPrimaryOrange),
      );
    }

    final results = isCityStep
        ? _filter<CityOption>(_cities, (c) => c.searchKey)
        : _filter<Country>(_countries, (c) => c.searchKey);

    if (results.isEmpty) {
      return Center(
        child: Text(
          isCityStep ? 'No matching city.' : 'No matching country.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kMuted),
        ),
      );
    }

    return ListView.separated(
      // The country list is short; a city list can run to tens of thousands
      // of rows, so keep the tiles cheap and let the builder stay lazy.
      itemCount: results.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: _kInputBorder),
      itemBuilder: (context, index) {
        final item = results[index];
        if (item is Country) {
          return _PickerTile(
            leading: Text(item.flag, style: const TextStyle(fontSize: 22)),
            label: item.name,
            trailing: const Icon(Icons.chevron_right, size: 20, color: _kMuted),
            onTap: () => _openCountry(item),
          );
        }

        final city = item as CityOption;
        return _PickerTile(
          leading: const Icon(Icons.location_on_outlined,
              size: 20, color: _kMuted),
          label: city.name,
          onTap: () => Navigator.of(context).pop(city),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kInputBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: _kMuted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: _kTitleDark,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFFB6BECC),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return AnimatedTapButton(
                onTap: controller.clear,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: _kMuted),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.leading,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final Widget leading;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTapButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 28, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _kTitleDark,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
