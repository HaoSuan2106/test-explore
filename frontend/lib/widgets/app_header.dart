import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Unified application header supporting standard, back navigation, and action buttons.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final bool showClose;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? trailingBadge;

  const AppHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.showClose = false,
    this.onBack,
    this.actions,
    this.leading,
    this.trailingBadge,
  });

  @override
  Size get preferredSize => const Size.fromHeight(54.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,

      toolbarHeight: 52,

      centerTitle: true,


      title: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 340,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: AppTypography.headlineMd.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            if (trailingBadge != null) ...[
              const SizedBox(width: AppSpacing.stackSm),
              trailingBadge!,
            ],
          ],
        ),
      ),



      leading: leading ??
          (showBack
              ? Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _CircularIconButton(
              icon: Icons.arrow_back,
              onPressed: onBack ?? () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          )
              : null),

      leadingWidth: showBack || leading != null ? 72 : 0,

      actions: [
        if (showClose)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CircularIconButton(
              icon: Icons.close,
              onPressed: onBack ?? () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          )
        else if (actions != null) ...[
          ...actions!,
          const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircularIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            icon,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}