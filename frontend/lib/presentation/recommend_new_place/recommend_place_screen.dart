import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/content_constraint.dart';
import '../navigation/app_navigation.dart';
import 'recommend_place_draft.dart';
import 'wizard_step_indicator.dart';

/// STEP 1 of the Recommend Place wizard — Place Details.
///
/// Collects the place name, category and description with inline validation,
/// then continues to STEP 2 (Direct Map Location) carrying a
/// [RecommendPlaceDraft] as navigation `extra`.
class RecommendPlaceScreen extends StatefulWidget {
  /// When the user returns from STEP 4 ("Edit Details") the draft is passed
  /// back so the form is re-filled instead of starting from scratch.
  final RecommendPlaceDraft? initialDraft;

  const RecommendPlaceScreen({super.key, this.initialDraft});

  @override
  State<RecommendPlaceScreen> createState() => _RecommendPlaceScreenState();
}

class _RecommendPlaceScreenState extends State<RecommendPlaceScreen> {
  final TextEditingController _placeNameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  String? _selectedCategory;
  String? _placeNameError;
  String? _categoryError;
  String? _descriptionError;

  static const List<String> _categories = [
    'Café',
    'Restaurant',
    'Scenic Point',
    'Historical Site',
    'Nature & Parks',
    'Shopping & Market',
  ];

  @override
  void initState() {
    super.initState();
    // Re-fill the form when returning from "Edit Details" on the Review step.
    final draft = widget.initialDraft;
    if (draft != null) {
      _placeNameCtrl.text = draft.name;
      _descCtrl.text = draft.description;
      _selectedCategory = draft.category;
    }
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
      _placeNameError = placeName.isEmpty ? 'Place name is required.' : null;
      _categoryError =
          _selectedCategory == null ? 'Please select a category.' : null;
      _descriptionError = description.isEmpty ? 'Description is required.' : null;
    });

    if (_placeNameError != null ||
        _categoryError != null ||
        _descriptionError != null) {
      return;
    }

    // Carry the collected details into STEP 2 (Direct Map Location).
    AppNavigation.toRecommendLocation(
      context,
      draft: RecommendPlaceDraft(
        name: placeName,
        category: _selectedCategory!,
        description: description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Recommend New Place',
        showBack: true, // Left-aligned circular back arrow
      ),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: Column(
            children: [
              // Wizard progress
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.containerMargin, 4, AppSpacing.containerMargin, 0),
                child: const WizardStepIndicator(current: 1),
              ),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.stackLg),
                      Text(
                        'Place Details',
                        style: AppTypography.headlineMd,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tell us about the hidden gem you want to recommend.',
                        style: AppTypography.bodyMd.copyWith(
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.stackLg),

                      // 1. Place Name Section
                      _buildFieldLabel('Place Name', isRequired: true),
                      const SizedBox(height: AppSpacing.stackSm),
                      _buildPlaceNameInput(),
                      if (_placeNameError != null) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            _placeNameError!,
                            style: AppTypography.labelSm
                                .copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.stackLg),

                      // 2. Category Section
                      _buildFieldLabel('Category', isRequired: true),
                      const SizedBox(height: AppSpacing.stackSm),
                      _buildCategoryDropdown(),
                      if (_categoryError != null) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            _categoryError!,
                            style: AppTypography.labelSm
                                .copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.stackLg),

                      // 3. Description Section
                      _buildFieldLabel('Description', isRequired: true),
                      const SizedBox(height: AppSpacing.stackSm),
                      _buildDescriptionInput(),
                      if (_descriptionError != null) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            _descriptionError!,
                            style: AppTypography.labelSm
                                .copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sectionGap),
                    ],
                  ),
                ),
              ),

              // 4. Continue to STEP 2 (Map Location)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
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
          color: _placeNameError != null ? AppColors.error : AppColors.outlineVariant,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _placeNameCtrl,
        maxLength: 150,
        style: AppTypography.bodyMd,
        decoration: InputDecoration(
          hintText: 'Enter Place Name',
          hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          counterText: '',
        ),
        onChanged: (_) {
          if (_placeNameError != null) {
            setState(() => _placeNameError = null);
          }
        },
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(
          color: _categoryError != null ? AppColors.error : AppColors.outlineVariant,
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          hint: Text(
            'Select a category',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          items: _categories
              .map((c) => DropdownMenuItem(
            value: c,
            child: Text(c, style: AppTypography.bodyMd),
          ))
              .toList(),
          onChanged: (val) {
            setState(() {
              _selectedCategory = val;
              _categoryError = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _descCtrl,
        maxLines: 5,
        maxLength: 500,
        style: AppTypography.bodyMd,
        decoration: InputDecoration(
          hintText: 'Tell us more about this place',
          hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
          border: InputBorder.none,
          isDense: true,
          counterText: '',
        ),
        onChanged: (_) {
          if (_descriptionError != null) {
            setState(() => _descriptionError = null);
          }
        },
      ),
    );
  }
}
