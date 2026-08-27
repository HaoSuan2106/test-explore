import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_header.dart';

/// Parameters passed to the transient loading screen so each operation can
/// provide its own copy while keeping the shared animation/design.
class LoadingStateArgs {
  final String? title;
  final String? heading;
  final String? message;

  const LoadingStateArgs({this.title, this.heading, this.message});
}

/// Full-screen loading state with a spinner, operation-specific copy, and a
/// lock icon. Kept in the shared status architecture so every deletion /
/// removal flow reuses the same animation and visual design.
class LoadingStateScreen extends StatelessWidget {
  final String title;
  final String heading;
  final String message;

  const LoadingStateScreen({
    super.key,
    this.title = 'Please Wait',
    this.heading = 'Removing...',
    this.message =
        'We are safely removing the selected item. Please wait a moment.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(title: title, showBack: true),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                Text(heading, style: AppTypography.headlineLg),
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  message,
                  style: AppTypography.bodyMd,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.stackLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text('Please do not close this screen',
                        style: AppTypography.labelSm),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}