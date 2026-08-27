import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_button.dart';

class StatusFeedbackScreen extends StatelessWidget {
  final String title;
  final String heading;
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final bool isDestructive;

  const StatusFeedbackScreen({
    super.key,
    required this.title,
    required this.heading,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(title: title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: iconColor),
              ),
              const SizedBox(height: AppSpacing.stackLg),
              Text(
                heading,
                style: AppTypography.headlineLg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                message,
                style: AppTypography.bodyMd,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                text: primaryButtonText,
                onPressed: onPrimaryPressed,
                variant: isDestructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
              ),
              if (secondaryButtonText != null) ...[
                const SizedBox(height: AppSpacing.stackMd),
                AppButton(
                  text: secondaryButtonText!,
                  onPressed: onSecondaryPressed,
                  variant: AppButtonVariant.outline,
                ),
              ],
              const SizedBox(height: AppSpacing.stackMd),
            ],
          ),
        ),
      ),
    );
  }
}