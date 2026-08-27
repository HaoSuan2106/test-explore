import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../navigation/app_navigation.dart';
import 'recommend_place_draft.dart';
import 'wizard_step_indicator.dart';

/// STEP 2 of the Recommend Place wizard — Direct Map Location.
///
/// The user sees a full-screen map with a fixed centre pin. Dragging the map
/// moves the area under the pin; the location (address + lat/lng) is
/// determined from the map centre. This replaces the old tap-to-place marker
/// pattern.
class RecommendLocationScreen extends StatefulWidget {
  final RecommendPlaceDraft draft;

  const RecommendLocationScreen({super.key, required this.draft});

  @override
  State<RecommendLocationScreen> createState() =>
      _RecommendLocationScreenState();
}

class _RecommendLocationScreenState extends State<RecommendLocationScreen> {
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(3.1390, 101.6869); // KL, Malaysia

  /// The centre of the map (under the fixed pin) — initialised from the
  /// draft if the user already picked a location, otherwise falls back to KL.
  late LatLng _selectedPoint;

  /// Mock address derived deterministically from the current centre.
  late String _currentAddress;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _selectedPoint = (d.latitude != null && d.longitude != null)
        ? LatLng(d.latitude!, d.longitude!)
        : _defaultCenter;
    _currentAddress = _mockAddressFor(_selectedPoint);
  }

  /// Deterministic KL-area address based on lat/lng so the map always produces
  /// a plausible street name without a real reverse-geocoder.
  String _mockAddressFor(LatLng point) {
    const streets = [
      'Jalan Tun H.S. Lee, Kuala Lumpur',
      'Jalan Ampang, Kuala Lumpur',
      'Jalan Bukit Bintang, Kuala Lumpur',
      'Jalan Petaling, Kuala Lumpur',
      'Jalan Alor, Kuala Lumpur',
      'Jalan Raja Chulan, Kuala Lumpur',
      'Jalan Sultan Ismail, Kuala Lumpur',
      'Jalan P. Ramlee, Kuala Lumpur',
    ];
    final index = ((point.latitude * 10000).round() +
            (point.longitude * 10000).round() * 3)
        .abs() %
        streets.length;
    return streets[index];
  }

  void _onUseLocation() {
    AppNavigation.toRecommendLocationPreview(
      context,
      draft: widget.draft.copyWith(
        address: _currentAddress,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Choose Location',
        showBack: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.containerMargin, 4, AppSpacing.containerMargin, 0),
              child: const WizardStepIndicator(current: 2),
            ),
            const SizedBox(height: AppSpacing.stackSm),

            // Map with fixed center pin
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 14,
                      onPositionChanged: (camera, hasGesture) {
                        setState(() {
                          _selectedPoint = camera.center;
                          _currentAddress = _mockAddressFor(camera.center);
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.explore_my',
                      ),
                    ],
                  ),
                  // Fixed center pin overlay — never moves; the map moves
                  // beneath it.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 48,
                              color: AppColors.primary,
                            ),
                            // Small shadow under the pin
                            Container(
                              width: 12,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: AppRadii.roundedFull,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Location info + actions
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Address card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: AppRadii.roundedDefault,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentAddress,
                            style: AppTypography.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_selectedPoint.latitude.toStringAsFixed(6)}, '
                    '${_selectedPoint.longitude.toStringAsFixed(6)}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Use This Location',
                      icon: Icons.check,
                      onPressed: _onUseLocation,
                    ),
                  ),
                  Text(
                    'Drag the map to move the pin to the correct location.',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}