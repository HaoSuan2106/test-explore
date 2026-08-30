import 'package:flutter/foundation.dart';

import '../../api_communication/http_client/http_client.dart';

/// Manages the user's per-district visit-count breakdown, used to color
/// the Personal Exploration Map heatmap.
class ExplorationMapProvider extends ChangeNotifier {
  ExplorationMapProvider({required HttpClient httpClient}) : _httpClient = httpClient;

  final HttpClient _httpClient;

  Map<String, int> _visitCounts = {};
  bool isLoading = false;
  String? errorMessage;

  Map<String, int> get visitCounts => Map.unmodifiable(_visitCounts);

  Future<void> loadExplorationMap() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _visitCounts = await _httpClient.getExplorationMap();
    } catch (e) {
      errorMessage = 'Failed to load exploration map.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}