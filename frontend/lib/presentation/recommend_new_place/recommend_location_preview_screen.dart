import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/content_constraint.dart';
import '../navigation/app_navigation.dart';
import 'photo_thumbnail.dart';
import 'recommend_place_draft.dart';
import 'wizard_step_indicator.dart';

/// STEP 3 of the Recommend Place wizard — Location Preview.
///
/// Confirms the coordinates picked on the STEP 2 map. The map is read-only
/// (fixed marker at the chosen point). "Change Location" pops back to the map;
/// "Continue" advances to STEP 4 (Review). Place information from Step 1
/// (name, primaryType, description, photos) is also shown in preview.
/// No address is displayed — location is the selected latitude/longitude only.
class RecommendLocationPreviewScreen extends StatefulWidget {
  final RecommendPlaceDraft draft;

  const RecommendLocationPreviewScreen({super.key, required this.draft});

  @override
  State<RecommendLocationPreviewScreen> createState() =>
      _RecommendLocationPreviewScreenState();
}

class _RecommendLocationPreviewScreenState
    extends State<RecommendLocationPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final point = (draft.latitude != null && draft.longitude != null)
        ? LatLng(draft.latitude!, draft.longitude!)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Preview Location',
        showBack: true,
      ),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.containerMargin, 4, AppSpacing.containerMargin, 0),
                child: const WizardStepIndicator(current: 3),
              ),
              const SizedBox(height: AppSpacing.stackSm),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.stackMd),
                      Text(
                        'Confirm the Location',
                        style: AppTypography.headlineMd,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This is the exact spot that will be attached to your '
                        'recommendation.',
                        style: AppTypography.bodyMd.copyWith(
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.stackLg),

                      // Read-only map preview with the chosen marker. When no
                      // real coordinates were picked (point == null) an empty
                      // state is shown — never a map centered on fake data.
                      ClipRRect(
                        borderRadius: AppRadii.roundedDefault,
                        child: SizedBox(
                          height: 260,
                          width: double.infinity,
                          child: point == null
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: AppRadii.roundedDefault,
                                    border: Border.all(
                                        color: AppColors.outlineVariant),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'No location selected yet.',
                                      style: TextStyle(
                                        color: Color(0xff777777),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              : FlutterMap(
                                  options: MapOptions(
                                    initialCenter: point,
                                    initialZoom: 15,
                                    interactionOptions:
                                        const InteractionOptions(
                                      flags: InteractiveFlag.none,
                                    ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.example.explore_my',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: point,
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.location_on,
                                            size: 40,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackMd),

                      // Place information carried from Step 1
                      if (draft.name.trim().isNotEmpty) ...[
                        _buildInfoRow(
                          icon: Icons.place_outlined,
                          title: 'Place Name',
                          value: draft.name,
                        ),
                        const SizedBox(height: AppSpacing.stackSm),
                      ],
                      if (draft.primaryType.trim().isNotEmpty) ...[
                        _buildInfoRow(
                          icon: Icons.category_outlined,
                          title: 'Primary Type',
                          value: draft.primaryType,
                        ),
                        const SizedBox(height: AppSpacing.stackSm),
                      ],
                      if (draft.description.trim().isNotEmpty) ...[
                        _buildInfoRow(
                          icon: Icons.notes_outlined,
                          title: 'Description',
                          value: draft.description,
                        ),
                        const SizedBox(height: AppSpacing.stackSm),
                      ],

                      // Photos carried from Step 1
                      if (draft.photoPaths.isNotEmpty) ...[
                        Text(
                          'Photos (${draft.photoPaths.length})',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPhotoGrid(draft.photoPaths),
                        const SizedBox(height: AppSpacing.stackMd),
                      ],

                      // Coordinates card
                      _buildInfoRow(
                        icon: Icons.my_location,
                        title: 'Coordinates',
                        value: point == null
                            ? 'Not selected'
                            : '${point.latitude.toStringAsFixed(6)}, '
                                '${point.longitude.toStringAsFixed(6)}',
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Change Location',
                        icon: Icons.edit_location_alt_outlined,
                        variant: AppButtonVariant.outline,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gutterMd),
                    Expanded(
                      child: AppButton(
                        text: 'Continue',
                        icon: Icons.arrow_forward,
                        onPressed: () => AppNavigation.toRecommendReview(
                            context, draft: draft),
                      ),
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

  /// Read-only photo thumbnails for the preview. Uses the same local paths
  /// carried in the draft (uploaded only at submission). Invalid/corrupt files
  /// fall back to a broken-image placeholder — never a crash.
  Widget _buildPhotoGrid(List<String> paths) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return PhotoThumb(
            path: paths[index],
            width: 96,
            height: 96,
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}