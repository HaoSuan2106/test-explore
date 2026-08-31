import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_header.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_error_state.dart';
import '../../../../widgets/app_feedback.dart';
import '../../../../providers/post_review/post_provider.dart';
import '../../../../models/post_review/post_model.dart';
import '../../navigation/app_navigation.dart';

class SelectAttractionScreen extends StatefulWidget {
  const SelectAttractionScreen({super.key});

  @override
  State<SelectAttractionScreen> createState() => _SelectAttractionScreenState();
}

class _SelectAttractionScreenState extends State<SelectAttractionScreen> {
  List<EligibleAttractionModel> _attractions = [];
  String? _selectedAttractionId;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // Defer the load until after the first frame so the provider's
    // notifyListeners() never runs while the widget tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAttractions();
    });
  }

  Future<void> _loadAttractions() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final provider = context.read<PostProvider>();
    await provider.loadEligibleAttractions();
    if (!mounted) return;
    setState(() {
      _attractions = provider.eligibleAttractions;
      _loadError = provider.errorMessage;
      _isLoading = false;
      if (_attractions.isNotEmpty) {
        _selectedAttractionId = _attractions.first.placeId;
      }
    });
  }

  void _onContinue() {
    if (_selectedAttractionId == null) {
      AppFeedback.show(context, message: 'Please select an attraction to continue.', isSuccess: false);
      return;
    }

    final selected = _attractions.firstWhere((a) => a.placeId == _selectedAttractionId);
    setDraftAndNavigate(selected);
  }

  void setDraftAndNavigate(EligibleAttractionModel selected) {
    final provider = context.read<PostProvider>();
    final location = selected.name;
    provider.setDraft(
      title: '',
      description: '',
      location: location,
      taggedPlaceId: selected.placeId,
      photos: [],
    );
    AppNavigation.toCreatePost(
      context,
      attractionName: selected.name,
      attractionLocation: location,
      attractionId: selected.placeId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Select Attraction',
        showBack: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null && _attractions.isEmpty
                ? _buildErrorState()
                : _attractions.isNotEmpty
                    ? _buildSelectionList()
                    : _buildEmptyState(),
      ),
    );
  }

  Widget _buildSelectionList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'Choose an attraction',
            style: AppTypography.headlineLg.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You can only create a post about attractions you\'ve explored.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Text(
            'Eligible Attractions (${_attractions.length})',
            style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Expanded(
            child: ListView.builder(
              itemCount: _attractions.length,
              itemBuilder: (context, index) {
                final attraction = _attractions[index];
                final isSelected = attraction.placeId == _selectedAttractionId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
                  child: _buildAttractionCard(attraction, isSelected),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AppButton(
              text: 'Continue to Create Post',
              onPressed: _onContinue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttractionCard(EligibleAttractionModel attraction, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedAttractionId = attraction.placeId),
      borderRadius: AppRadii.roundedLg,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadii.roundedLg,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Category icon placeholder
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadii.roundedDefault,
              ),
              child: Icon(
                _categoryIcon(attraction.category),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.stackMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attraction.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          attraction.address,
                          style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attraction.category,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.outline,
                  width: isSelected ? 6.0 : 1.5,
                ),
                color: isSelected ? AppColors.background : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'waterfall':
        return Icons.water_drop;
      case 'cave':
        return Icons.landscape;
      case 'viewpoint':
        return Icons.visibility;
      case 'heritage':
      case 'historical':
        return Icons.history;
      case 'nature':
      case 'park':
        return Icons.park;
      default:
        return Icons.place;
    }
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'Choose an attraction',
            style: AppTypography.headlineLg.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'You can only create a post about attractions you\'ve explored.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          AppErrorState(
            title: 'Could not load attractions',
            message: _loadError ?? 'Please try again.',
            onRetry: _loadAttractions,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'Choose an attraction',
            style: AppTypography.headlineLg.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'You can only create a post about attractions you\'ve explored.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDF0ED),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.backpack_outlined,
                      size: 64,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                Text(
                  'No eligible attractions yet',
                  style: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'You need to explore more attractions before you can create a community post.',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AppButton(
              text: 'Back to Post Feed',
              icon: Icons.arrow_back,
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}