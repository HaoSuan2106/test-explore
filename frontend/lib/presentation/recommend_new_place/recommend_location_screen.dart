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
/// moves the area under the pin; the location (latitude + longitude) is taken
/// from the map centre. No reverse-geocoded address is requested or shown —
/// the selected map coordinates are the only location source (Part C/H).
///
/// Google Places remains POSTPONED; the map stays on OpenStreetMap.
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

  /// Notifies the bottom location panel of the latest map centre during a
  /// drag, so only that small panel rebuilds — NOT the whole screen (the map
  /// tiles keep rendering without a full rebuild per camera move).
  late final ValueNotifier<LatLng> _selectedNotifier;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _selectedPoint = (d.latitude != null && d.longitude != null)
        ? LatLng(d.latitude!, d.longitude!)
        : _defaultCenter;
    _selectedNotifier = ValueNotifier<LatLng>(_selectedPoint);
  }

  /// High-frequency map movement: cheaply track the centre so the "Use This
  /// Location" action is always correct, and push it to the bottom panel
  /// notifier. No full-screen setState per move; no address lookup occurs.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _selectedPoint = camera.center;
    _selectedNotifier.value = camera.center;
  }

  void _onUseLocation() {
    AppNavigation.toRecommendLocationPreview(
      context,
      draft: widget.draft.copyWith(
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _selectedNotifier.dispose();
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
                      onPositionChanged: _onPositionChanged,
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
                  // The coordinates update while the map is dragged. A
                  // ValueListenableBuilder scopes the coordinate rebuild to
                  // just this panel, so the map never re-builds per move.
                  ValueListenableBuilder<LatLng>(
                    valueListenable: _selectedNotifier,
                    builder: (context, point, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${point.latitude.toStringAsFixed(6)}, '
                            '${point.longitude.toStringAsFixed(6)}',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
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