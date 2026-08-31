import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Shared full-screen / centered error state used across screens.
///
/// Reference style: `SelectAttractionScreen._buildErrorState()`
/// (Icons.error_outline, size 56, headlineMd title, bodyMd message,
/// stackLg gap before an outline Retry `AppButton`).
///
/// The error block is fully centered. [message] is optional and
/// horizontally padded so long error text never touches the screen edges;
/// [onRetry] is optional — when null no button is rendered.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryText = 'Retry',
    this.icon = Icons.error_outline,
    this.iconSize = 56,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    final msg = message;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: AppColors.error,
          ),

          const SizedBox(height: AppSpacing.stackMd),

          Text(
            title,
            style: AppTypography.headlineMd,
            textAlign: TextAlign.center,
          ),

          if (msg != null && msg.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                msg,
                style: AppTypography.bodyMd,
                textAlign: TextAlign.center,
              ),
            ),
          ],

          if (retry != null) ...[
            const SizedBox(height: AppSpacing.stackLg),

            OutlinedButton(
              onPressed: retry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    retryText,
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          ],
        ],
      ),
    );
  }
}