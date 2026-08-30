import 'package:flutter/foundation.dart';

import '../../api_communication/http_client/http_client.dart';
import '../../models/foot_tracker/exploration_model.dart';
import '../session_scoped_provider.dart';

/// Manages the user's Favourite Place list — loading and deleting
/// selected places. Now backed by real backend calls under
/// FootTrackerController.
class FavouriteProvider extends ChangeNotifier implements SessionScopedProvider {
  FavouriteProvider({required HttpClient httpClient}) : _httpClient = httpClient;

  final HttpClient _httpClient;

  List<FavouritePlace> _places = [];
  bool isLoading = false;
  String? errorMessage;

  List<FavouritePlace> get places => List.unmodifiable(_places);

  Future<void> loadPlaces() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _places = await _httpClient.getFavouritePlaces();
    } catch (e) {
      errorMessage = 'Failed to load favourite places.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deletePlaces(Set<String> ids) async {
    try {
      await _httpClient.deleteFavouritePlaces(ids.map(int.parse).toList());
      _places = _places.where((p) => !ids.contains(p.id)).toList();
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to remove favourite place(s).';
      notifyListeners();
    }
  }

  bool isFavourite(String placeId) => _places.any((p) => p.placeId == placeId);

  Future<void> addFavouritePlace({
    required String placeId,
    required String name,
    required String primaryType,
    String? address,
    required double latitude,
    required double longitude,
  }) async {
    await _httpClient.addFavouritePlace(
      placeId: placeId,
      name: name,
      primaryType: primaryType,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    await loadPlaces();
  }

  Future<void> removeFavouritePlaceByPlaceId(String placeId) async {
    final match = _places.where((p) => p.placeId == placeId);
    if (match.isEmpty) return;
    await deletePlaces({match.first.id});
  }

  @override
  void clearSessionData() {
    _places = [];
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}