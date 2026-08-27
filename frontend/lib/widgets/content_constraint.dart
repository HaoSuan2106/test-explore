import 'package:flutter/material.dart';

/// Centers [child] and caps its width so tablet/desktop viewports do not
/// stretch content full-bleed across the entire screen.
///
/// Mobile viewports (narrower than [maxWidth]) remain effectively full-width
/// because the constraint only binds when the available width exceeds it.
///
/// Use ~600 for forms and ~800 for feed/content screens.
class ContentConstraint extends StatelessWidget {
  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = 600,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
