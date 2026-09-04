import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/content_constraint.dart';
import '../../providers/hidden_place/hidden_place_provider.dart';
import '../navigation/app_navigation.dart';
import 'photo_thumbnail.dart';
import 'recommend_place_draft.dart';
import 'wizard_step_indicator.dart';

/// STEP 1 of the Recommend Place wizard — Place Details.
///
/// Collects:
/// - Place name
/// - Primary Type (options sourced from hidden_place_cache, never hard-coded)
/// - Price level
/// - Description
/// - Photos
///
/// Continues to STEP 2 carrying [RecommendPlaceDraft].
class RecommendPlaceScreen extends StatefulWidget {
  /// When user returns from STEP 4 ("Edit Details"),
  /// draft is passed back so form can be re-filled.
  final RecommendPlaceDraft? initialDraft;

  const RecommendPlaceScreen({
    super.key,
    this.initialDraft,
  });

  @override
  State<RecommendPlaceScreen> createState() =>
      _RecommendPlaceScreenState();
}

class _RecommendPlaceScreenState
    extends State<RecommendPlaceScreen> {
  final TextEditingController _placeNameCtrl =
  TextEditingController();

  final TextEditingController _descCtrl =
  TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedPrimaryType;
  int? _selectedPriceLevel;

  String? _placeNameError;
  String? _primaryTypeError;
  String? _priceLevelError;
  String? _descriptionError;
  String? _photosError;

  List<String> _photoPaths = [];

  /// Distinct Primary Type options loaded from `hidden_place_cache` via the
  /// backend (`GET /api/recommended-places/primary-types`). This is the ONLY
  /// source of options — there is deliberately NO hard-coded list.
  List<String> _primaryTypes = [];
  bool _isPrimaryTypesLoading = false;
  String? _primaryTypesError;

  static const List<int> _priceLevels = [
    0,
    1,
    2,
    3,
    4,
  ];

  @override
  void initState() {
    super.initState();

    final draft = widget.initialDraft;

    if (draft != null) {
      _placeNameCtrl.text = draft.name;
      _descCtrl.text = draft.description;

      _selectedPrimaryType = draft.primaryType;
      _selectedPriceLevel = draft.priceLevel;

      _photoPaths = List<String>.from(
        draft.photoPaths,
      );
    }

    // Primary Type options come live from hidden_place_cache via the backend
    // (never a hard-coded list). Load them once on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPrimaryTypes();
      }
    });
  }

  /// Fetches Primary Type options from the backend (sourced from
  /// hidden_place_cache.primary_type). The widget keeps its own copy so the
  /// dropdown reflects loading/error/empty states without a full re-render.
  Future<void> _loadPrimaryTypes() async {
    final provider = context.read<HiddenPlaceProvider>();
    if (provider.primaryTypes.isNotEmpty) {
      // Already loaded (e.g. re-entering the wizard) — reuse the cached options.
      setState(() {
        _primaryTypes = provider.primaryTypes;
      });
      return;
    }

    setState(() {
      _isPrimaryTypesLoading = true;
      _primaryTypesError = null;
    });

    await provider.loadPrimaryTypes();

    if (!mounted) return;
    setState(() {
      _isPrimaryTypesLoading = provider.isPrimaryTypesLoading;
      _primaryTypesError = provider.primaryTypesError;
      _primaryTypes = provider.primaryTypes;
    });
  }

  @override
  void dispose() {
    _placeNameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onContinue() {
    final placeName = _placeNameCtrl.text.trim();
    final description = _descCtrl.text.trim();

    setState(() {
      _placeNameError =
      placeName.isEmpty
          ? 'Place name is required.'
          : null;

      // If hidden_place_cache currently has no usable Primary Type values the
      // form cannot proceed — the UI never invents fallback categories.
      _primaryTypeError = _selectedPrimaryType == null
          ? (_primaryTypes.isEmpty
          ? 'No Primary Types are currently available. Please try again later.'
          : 'Please select a Primary Type.')
          : null;

      // DB alignment (latest_v2.sql): description and price_level columns are
      // NULL-able, so both are OPTIONAL at every layer — the UI, the API and
      // the database agree. Empty description and no price level are allowed.
      _priceLevelError = null;

      _descriptionError = null;

      _photosError =
      _photoPaths.isEmpty
          ? 'Please add at least one photo.'
          : null;
    });

    if (_placeNameError != null ||
        _primaryTypeError != null ||
        _priceLevelError != null ||
        _descriptionError != null ||
        _photosError != null) {
      return;
    }

    final draft = RecommendPlaceDraft(
      name: placeName,
      primaryType: _selectedPrimaryType!,
      description: description,
      priceLevel: _selectedPriceLevel,
      photoPaths: _photoPaths,
      latitude: widget.initialDraft?.latitude,
      longitude: widget.initialDraft?.longitude,
      editingSubmissionId: widget.initialDraft?.editingSubmissionId,
    );

    AppNavigation.toRecommendLocation(
      context,
      draft: draft,
    );
  }

  /// Maximum number of photos a recommendation may have.
  ///
  /// Mirrors the authoritative backend limit (3) so the user is rejected in
  /// Step 1 instead of discovering the limit at submission time.
  static const int maxPhotos = 3;

  Future<void> _pickPhotos() async {
    if (_photoPaths.length >= maxPhotos) {
      setState(() {
        _photosError = 'You can add up to $maxPhotos photos.';
      });
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (images.isEmpty) {
        return;
      }

      final acceptedCount = acceptedPhotoCount(
        currentCount: _photoPaths.length,
        pickedCount: images.length,
        maxPhotos: maxPhotos,
      );
      final accepted = images.take(acceptedCount).toList();
      final rejectedCount = images.length - accepted.length;

      setState(() {
        _photoPaths.addAll(
          accepted.map((image) => image.path),
        );

        if (rejectedCount > 0) {
          _photosError =
          'You can add up to $maxPhotos photos. Only ${accepted.length} '
              '${accepted.length == 1 ? 'photo was' : 'photos were'} '
              'added; $rejectedCount ${rejectedCount == 1 ? 'was' : 'were'} skipped.';
        } else {
          _photosError = null;
        }
      });
    } catch (_) {
      setState(() {
        _photosError =
        'Unable to select photos. Please try again.';
      });
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _photoPaths.length) {
      return;
    }

    setState(() {
      _photoPaths.removeAt(index);

      if (_photoPaths.isNotEmpty) {
        _photosError = null;
      }
    });
  }

  String _priceLevelLabel(int value) {
    switch (value) {
      case 0:
        return 'Free';

      case 1:
        return r'$';

      case 2:
        return r'$$';

      case 3:
        return r'$$$';

      case 4:
        return r'$$$$';

      default:
        return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Recommend New Place',
        showBack: true,
      ),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.containerMargin,
                  4,
                  AppSpacing.containerMargin,
                  0,
                ),
                child: const WizardStepIndicator(
                  current: 1,
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: AppSpacing.stackLg,
                      ),

                      Text(
                        'Place Details',
                        style: AppTypography.headlineMd,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Tell us about the place you want to recommend.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(
                        height: AppSpacing.stackLg,
                      ),

                      // ==================================================
                      // 1. PLACE NAME
                      // ==================================================

                      _buildFieldLabel(
                        'Place Name',
                        isRequired: true,
                      ),

                      const SizedBox(
                        height: AppSpacing.stackSm,
                      ),

                      _buildPlaceNameInput(),

                      if (_placeNameError != null) ...[
                        const SizedBox(height: 4),
                        _buildErrorText(
                          _placeNameError!,
                        ),
                      ],

                      const SizedBox(
                        height: AppSpacing.stackLg,
                      ),

                      // ==================================================
                      // 2. PRIMARY TYPE
                      // ==================================================

                      _buildFieldLabel(
                        'Primary Type',
                        isRequired: true,
                      ),

                      const SizedBox(
                        height: AppSpacing.stackSm,
                      ),

                      _buildPrimaryTypeDropdown(),

                      if (_primaryTypeError != null) ...[
                        const SizedBox(height: 4),
                        _buildErrorText(
                          _primaryTypeError!,
                        ),
                      ],

                      const SizedBox(
                        height: AppSpacing.stackLg,
                      ),

                      // ==================================================
                      // 3. PRICE LEVEL
                      // ==================================================

                      _buildFieldLabel(
                        'Price Level',
                        isRequired: false,
                      ),

                      const SizedBox(
                        height: AppSpacing.stackSm,
                      ),

                      _buildPriceLevelDropdown(),

                      if (_priceLevelError != null) ...[
                        const SizedBox(height: 4),
                        _buildErrorText(
                          _priceLevelError!,
                        ),
                      ],

                      const SizedBox(
                        height: AppSpacing.stackLg,
                      ),

                      // ==================================================
                      // 4. DESCRIPTION
                      // ==================================================

                      _buildFieldLabel(
                        'Description',
                        isRequired: false,
                      ),

                      const SizedBox(
                        height: AppSpacing.stackSm,
                      ),

                      _buildDescriptionInput(),

                      if (_descriptionError != null) ...[
                        const SizedBox(height: 4),
                        _buildErrorText(
                          _descriptionError!,
                        ),
                      ],

                      const SizedBox(
                        height: AppSpacing.stackLg,
                      ),

                      // ==================================================
                      // 5. PHOTOS
                      // ==================================================

                      _buildFieldLabel('Photos'),

                      const SizedBox(
                        height: AppSpacing.stackSm,
                      ),

                      _buildPhotosSection(),

                      if (_photosError != null) ...[
                        const SizedBox(height: 4),
                        _buildErrorText(
                          _photosError!,
                        ),
                      ],

                      const SizedBox(
                        height: AppSpacing.sectionGap,
                      ),
                    ],
                  ),
                ),
              ),

              // ============================================================
              // CONTINUE
              // ============================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
                child: AppButton(
                  text: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: _onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorText(String message) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        message,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.error,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(
      String label, {
        bool isRequired = false,
      }) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.labelLg.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceNameInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(
          color: _placeNameError != null
              ? AppColors.error
              : AppColors.outlineVariant,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: TextField(
        controller: _placeNameCtrl,
        maxLength: 150,
        style: AppTypography.bodyMd,
        decoration: InputDecoration(
          hintText: 'Enter Place Name',
          hintStyle: AppTypography.bodyMd.copyWith(
            color: AppColors.textMuted,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 12),
          counterText: '',
        ),
        onChanged: (_) {
          if (_placeNameError != null) {
            setState(() {
              _placeNameError = null;
            });
          }
        },
      ),
    );
  }

  Widget _buildPrimaryTypeDropdown() {
    // Loading: show a disabled container with a progress indicator.
    if (_isPrimaryTypesLoading && _primaryTypes.isEmpty) {
      return _buildDropdownContainer(
        hasError: _primaryTypeError != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading Primary Types...',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error: show the failure message with a Retry action (no crash, no blank).
    if (_primaryTypesError != null) {
      return _buildDropdownContainer(
        hasError: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _primaryTypesError!,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loadPrimaryTypes,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty: hidden_place_cache has no usable Primary Type values — surface it
    // clearly and never offer an invented fallback list.
    if (_primaryTypes.isEmpty) {
      return _buildDropdownContainer(
        hasError: _primaryTypeError != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No Primary Types are currently available.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildDropdownContainer(
      hasError: _primaryTypeError != null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPrimaryType,
          hint: Text(
            'Select a Primary Type',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.textSecondary,
          ),
          items: _primaryTypes
              .map(
                (primaryType) => DropdownMenuItem<String>(
              value: primaryType,
              child: Text(
                primaryType,
                style: AppTypography.bodyMd,
              ),
            ),
          )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedPrimaryType = value;
              _primaryTypeError = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPriceLevelDropdown() {
    return _buildDropdownContainer(
      hasError: _priceLevelError != null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedPriceLevel,
          hint: Text(
            'Select a price level',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.textSecondary,
          ),
          items: _priceLevels
              .map(
                (level) => DropdownMenuItem<int>(
              value: level,
              child: Text(
                _priceLevelLabel(level),
                style: AppTypography.bodyMd,
              ),
            ),
          )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedPriceLevel = value;
              _priceLevelError = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({
    required bool hasError,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(
          color: hasError
              ? AppColors.error
              : AppColors.outlineVariant,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildDescriptionInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(
          color: _descriptionError != null
              ? AppColors.error
              : AppColors.outlineVariant,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: TextField(
        controller: _descCtrl,
        maxLines: 5,
        maxLength: 500,
        style: AppTypography.bodyMd,
        decoration: InputDecoration(
          hintText: 'Tell us more about this place',
          hintStyle: AppTypography.bodyMd.copyWith(
            color: AppColors.textMuted,
          ),
          border: InputBorder.none,
          isDense: true,
          counterText: '',
        ),
        onChanged: (_) {
          if (_descriptionError != null) {
            setState(() {
              _descriptionError = null;
            });
          }
        },
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickPhotos,
          borderRadius: AppRadii.roundedDefault,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadii.roundedDefault,
              border: Border.all(
                color: _photosError != null
                    ? AppColors.error
                    : AppColors.outlineVariant,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 30,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add Photos',
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select photos of this place',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_photoPaths.isNotEmpty) ...[
          const SizedBox(height: 12),

          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photoPaths.length,
              separatorBuilder: (_, __) =>
              const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _buildPhotoPreview(index);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoPreview(int index) {
    final path = _photoPaths[index];

    return Stack(
      children: [
        PhotoThumb(
          path: path,
          width: 88,
          height: 88,
        ),

        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _removePhoto(index),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pure helper deciding how many newly picked photos may be added without
/// exceeding [maxPhotos] (the backend photo limit). Kept free of the widget
/// tree so the 0/1/2/3/4+ selection rules are unit-testable.
@visibleForTesting
int acceptedPhotoCount({
  required int currentCount,
  required int pickedCount,
  required int maxPhotos,
}) {
  if (currentCount >= maxPhotos || pickedCount <= 0) {
    return 0;
  }
  final remaining = maxPhotos - currentCount;
  return pickedCount < remaining ? pickedCount : remaining;
}
