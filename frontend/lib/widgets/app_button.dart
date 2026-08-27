import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outline, destructive, ghost }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final IconData? suffixIcon;
  final bool isFullWidth;
  final bool isLoading;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.suffixIcon,
    this.isFullWidth = true,
    this.isLoading = false,
    this.height = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = isEnabled ? AppColors.primary : AppColors.surfaceDim;
        fg = isEnabled ? AppColors.onPrimary : AppColors.textMuted;
        break;
      case AppButtonVariant.secondary:
        bg = AppColors.surfaceCard;
        fg = AppColors.textPrimary;
        break;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = isEnabled ? AppColors.primary : AppColors.textMuted;
        border = BorderSide(
          color: isEnabled ? AppColors.primary : AppColors.outline,
          width: 1.5,
        );
        break;
      case AppButtonVariant.destructive:
        bg = isEnabled ? AppColors.error : AppColors.surfaceDim;
        fg = AppColors.onError;
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.textSecondary;
        break;
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.stackSm),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (suffixIcon != null && !isLoading) ...[
          const SizedBox(width: AppSpacing.stackSm),
          Icon(suffixIcon, size: 18, color: fg),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        // Min height only: labels may wrap (responsive), so the button can
        // grow vertically instead of overflowing its fixed-height Row.
        minHeight: height,
        minWidth: isFullWidth ? double.infinity : 0,
      ),
      child: Material(
        color: bg,
        borderRadius: AppRadii.roundedXl,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: AppRadii.roundedXl,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutterMd),
            decoration: BoxDecoration(
              borderRadius: AppRadii.roundedXl,
              border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}