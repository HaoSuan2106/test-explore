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

  @override
  void clearSessionData() {
    _places = [];
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}
