import 'dart:convert' show LineSplitter;

import 'package:flutter/services.dart' show rootBundle;

part 'world_cities_folds.dart';

/// A country the user can pick before narrowing down to a city.
class Country {
  const Country({required this.code, required this.name, required this.searchKey});

  /// ISO-3166 alpha-2, e.g. `MY`. Names the city asset for this country.
  final String code;
  final String name;

  /// [name] folded for matching — see [WorldCities.fold].
  final String searchKey;

  /// The flag emoji for [code], built from the regional-indicator letters.
  /// Renders as a flag wherever the platform has the glyphs and as two boxed
  /// letters where it doesn't — either way it never fails to draw.
  String get flag {
    if (code.length != 2) return '';
    const base = 0x1F1E6; // REGIONAL INDICATOR SYMBOL LETTER A
    return String.fromCharCodes([
      base + code.codeUnitAt(0) - 0x41,
      base + code.codeUnitAt(1) - 0x41,
    ]);
  }
}

/// One selectable city, as shown in the picker and stored on the profile.
class CityOption {
  const CityOption({
    required this.name,
    required this.country,
    required this.searchKey,
  });

  final String name;

  /// The country's display name, e.g. `Malaysia`.
  final String country;

  /// [name] folded for matching — read straight from the asset, which stores
  /// it precomputed alongside each city.
  final String searchKey;

  /// What gets written to `Profile.city` — "Kuala Lumpur, Malaysia".
  ///
  /// The country is part of the stored value because city names are not
  /// unique (there is a London in Canada, the UK and the US), so the name on
  /// its own would not say where the user actually is.
  String get label => '$name, $country';
}

/// The world's countries and their cities, backed by bundled assets so the
/// picker needs no network, no API key and no per-request quota.
///
/// `assets/data/countries.txt` lists `<ISO2>\t<Country>`, and each
/// `assets/data/cities/<ISO2>.txt` lists that country's cities as
/// `<fold key>\t<City>`. The fold key is the name lowercased with accents
/// stripped, precomputed at build time (see tools/build_world_cities.py) so a
/// typed query matches with a plain substring test and "munchen" still finds
/// "München". Splitting the data per country keeps each load to a few
/// kilobytes rather than the whole ~156k-city world list.
class WorldCities {
  WorldCities._();

  static List<Country>? _countries;
  static final Map<String, List<CityOption>> _citiesByCode = {};

  /// Every country that has cities, ordered by name.
  static Future<List<Country>> countries() async {
    final cached = _countries;
    if (cached != null) return cached;

    final text = await rootBundle.loadString('assets/data/countries.txt');
    final countries = <Country>[];
    for (final line in const LineSplitter().convert(text)) {
      final tab = line.indexOf('\t');
      if (tab == -1) continue;
      final name = line.substring(tab + 1);
      countries.add(Country(
        code: line.substring(0, tab),
        name: name,
        searchKey: fold(name),
      ));
    }
    return _countries = countries;
  }

  /// Every city in [country], ordered by name. Cached after the first load —
  /// the biggest single country is a few hundred kilobytes.
  static Future<List<CityOption>> citiesOf(Country country) async {
    final cached = _citiesByCode[country.code];
    if (cached != null) return cached;

    final text = await rootBundle.loadString(
      'assets/data/cities/${country.code}.txt',
    );
    final cities = <CityOption>[];
    for (final line in const LineSplitter().convert(text)) {
      final tab = line.indexOf('\t');
      if (tab == -1) continue;
      cities.add(CityOption(
        searchKey: line.substring(0, tab),
        name: line.substring(tab + 1),
        country: country.name,
      ));
    }
    return _citiesByCode[country.code] = cities;
  }

  /// Drops the cached city lists. Called when the picker closes, so a browse
  /// through several large countries doesn't hold their lists for the rest of
  /// the session. The (tiny) country list is kept.
  static void releaseCities() => _citiesByCode.clear();

  /// Normalises text the way the assets' fold keys were built: lowercase,
  /// with accented, stroked and ligature Latin letters mapped to plain ASCII,
  /// so a query typed on a plain keyboard ("osnabruck") matches "Osnabrück".
  ///
  /// Only used on the query and on country names at load; city fold keys come
  /// precomputed in the asset. The `_folds` table is generated alongside those
  /// assets — Dart has no Unicode normalisation in its SDK, so it cannot
  /// derive them, and a hand-written table drifts from the data.
  static String fold(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_folds[char] ?? char);
    }
    return buffer.toString();
  }
}
