import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/content_constraint.dart';
import '../navigation/app_navigation.dart';

/// Final screen of the Recommend Place wizard — Submission Success.
///
/// Reached after STEP 4 submit succeeds. Two exits:
///   - "View My Recommendations" → My Recommended Places
///   - "Back to Home" → Post Feed (Main shell)
class RecommendationSuccessScreen extends StatelessWidget {
  const RecommendationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'Recommendation Submitted',
        showBack: false,
      ),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 800,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.successContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                Text(
                  'Recommendation Submitted!',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineLg,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  'Your hidden gem is now under community voting. '
                  'It needs 5 verifications to earn the Verified Hidden Gem badge.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackLg * 2),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'View My Recommendations',
                    icon: Icons.place_outlined,
                    onPressed: () =>
                        AppNavigation.toMyRecommendedPlaces(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Back to Home',
                    icon: Icons.home_outlined,
                    variant: AppButtonVariant.outline,
                    onPressed: () => AppNavigation.toMain(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}