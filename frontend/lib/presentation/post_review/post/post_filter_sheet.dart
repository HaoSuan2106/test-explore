import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_button.dart';

/// Post Feed filter categories — the two-section filter tree from the final
/// architecture:
///
///   POST FEED → FILTER
///     MY ACTIVITY : Posted | Commented | Reported | Saved
///     DISCOVER    : Newest | Popularity
enum FeedFilterCategory { myActivity, discover }

/// The individual filter options inside the two sections.
enum FeedFilterOption { posted, commented, reported, newest, popularity, saved }

/// An immutable selection of the two-section Post Feed filter, including the
/// popularity engagement range used by DISCOVER → Popularity.
class FeedFilter {
  final FeedFilterCategory category;
  final FeedFilterOption option;

  /// Engagement window (likes + comments) for Discover → Popularity.
  final RangeValues popularityRange;

  const FeedFilter({
    this.category = FeedFilterCategory.discover,
    this.option = FeedFilterOption.newest,
    this.popularityRange = const RangeValues(0, 1000),
  });

  static const FeedFilter newest = FeedFilter(
    category: FeedFilterCategory.discover,
    option: FeedFilterOption.newest,
  );

  String get categoryLabel =>
      category == FeedFilterCategory.myActivity ? 'My Activity' : 'Discover';

  String get optionLabel {
    switch (option) {
      case FeedFilterOption.posted:
        return 'Posted';
      case FeedFilterOption.commented:
        return 'Commented';
      case FeedFilterOption.reported:
        return 'Reported';
      case FeedFilterOption.newest:
        return 'Newest';
      case FeedFilterOption.popularity:
        return 'Popularity';
      case FeedFilterOption.saved:
        return 'Saved';
    }
  }

  /// "2 – 150" style label for the popularity range (only meaningful for
  /// the popularity option).
  String get rangeLabel {
    final min = popularityRange.start.round();
    final max = popularityRange.end.round();
    return '$min – $max';
  }

  FeedFilter copyWith({
    FeedFilterCategory? category,
    FeedFilterOption? option,
    RangeValues? popularityRange,
  }) {
    return FeedFilter(
      category: category ?? this.category,
      option: option ?? this.option,
      popularityRange: popularityRange ?? this.popularityRange,
    );
  }
}

/// Bottom sheet hosting the two-section filter UI (MY ACTIVITY / DISCOVER)
/// plus the popularity engagement range slider. Pops with the chosen
/// [FeedFilter] via [onApply].
class PostFilterSheet extends StatefulWidget {
  final FeedFilter current;
  final ValueChanged<FeedFilter> onApply;

  const PostFilterSheet({
    super.key,
    required this.current,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required FeedFilter current,
    required ValueChanged<FeedFilter> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => PostFilterSheet(current: current, onApply: onApply),
    );
  }

  @override
  State<PostFilterSheet> createState() => _PostFilterSheetState();
}

class _PostFilterSheetState extends State<PostFilterSheet> {
  late FeedFilter _selection = widget.current;

  static const Map<FeedFilterOption, String> _labels = {
    FeedFilterOption.posted: 'Posted',
    FeedFilterOption.commented: 'Commented',
    FeedFilterOption.reported: 'Reported',
    FeedFilterOption.newest: 'Newest',
    FeedFilterOption.popularity: 'Popularity',
    FeedFilterOption.saved: 'Saved',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          20,
          AppSpacing.containerMargin,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Posts',
                  style: AppTypography.headlineMd.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'My Activity shows your community engagement; Discover shows the community feed.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.stackMd),

            // ---------------- MY ACTIVITY ----------------
            _sectionHeader('MY ACTIVITY'),
            _optionTile(FeedFilterOption.posted),
            _optionTile(FeedFilterOption.commented),
            _optionTile(FeedFilterOption.reported),
            _optionTile(FeedFilterOption.saved),

            const SizedBox(height: AppSpacing.stackLg),

            // ---------------- DISCOVER ----------------
            _sectionHeader('DISCOVER'),
            _optionTile(FeedFilterOption.newest),
            _optionTile(FeedFilterOption.popularity),
            if (_selection.option == FeedFilterOption.popularity)
              _popularityRange(),

            const SizedBox(height: AppSpacing.stackLg),
            AppButton(
              text: 'Apply Filter',
              icon: Icons.filter_alt_outlined,
              onPressed: () {
                Navigator.of(context).pop();
                widget.onApply(_selection);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _optionTile(FeedFilterOption option) {
    final selected = _selection.option == option;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() {
          _selection = _selection.copyWith(
            category: _categoryFor(option),
            option: option,
          );
        }),
        borderRadius: AppRadii.roundedDefault,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceCard,
            borderRadius: AppRadii.roundedDefault,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Text(_labels[option]!, style: AppTypography.bodyMd),
            ],
          ),
        ),
      ),
    );
  }

  FeedFilterCategory _categoryFor(FeedFilterOption option) {
    switch (option) {
      case FeedFilterOption.posted:
      case FeedFilterOption.commented:
      case FeedFilterOption.reported:
      case FeedFilterOption.saved:
        return FeedFilterCategory.myActivity;
      case FeedFilterOption.newest:
      case FeedFilterOption.popularity:
        return FeedFilterCategory.discover;
    }
  }

  Widget _popularityRange() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Engagement range (likes + comments)',
                style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                _selection.rangeLabel,
                style: AppTypography.labelLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          RangeSlider(
            values: _selection.popularityRange,
            min: 0,
            max: 1000,
            divisions: 100,
            labels: RangeLabels(
              _selection.popularityRange.start.round().toString(),
              _selection.popularityRange.end.round().toString(),
            ),
            activeColor: AppColors.primary,
            inactiveColor: AppColors.outlineVariant,
            onChanged: (values) => setState(() {
              _selection = _selection.copyWith(popularityRange: values);
            }),
          ),
        ],
      ),
    );
  }
}
