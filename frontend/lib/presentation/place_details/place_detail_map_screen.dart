import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'place_details_ui.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart' show PlaceData;

/// A minimal "map + place detail sheet" screen for opening a single known
/// place (e.g. from Exploration History's "View More"), without the
/// search bar / nearby-list logic that HiddenPlaceDiscoveryUi has.
class PlaceDetailMapScreen extends StatelessWidget {
  final PlaceData place;

  const PlaceDetailMapScreen({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: place.position, zoom: 16),
            markers: {
              Marker(markerId: MarkerId(place.placeId), position: place.position),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          PlaceDetailUI(
            place: place,
            onClose: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}