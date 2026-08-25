import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../api_communication/http_client/http_client.dart';
import '../../models/hidden_place/hidden_place_model.dart';

class HiddenPlaceProvider extends ChangeNotifier {
  HiddenPlaceProvider({required HttpClient httpClient}) : _httpClient = httpClient;

  final HttpClient _httpClient;

  List<HiddenPlaceModel> places = [];
  bool isLoading = false;
  String? errorMessage;

  /// Fetches hidden-gem places near (latitude, longitude) from the backend and replaces
  /// the current list. Backend handles the Google Places call + the hidden-score ranking,
  /// so this is just "ask for places near here" from the UI's point of view.
  Future<void> loadNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    List<String>? types,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      places = await _httpClient.discoverHiddenPlaces(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        types: types,
      );
    } on DioException {
      errorMessage = 'Failed to load hidden places nearby.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
