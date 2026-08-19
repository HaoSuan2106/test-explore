import 'package:flutter/material.dart';

/// A press-scale + ripple wrapper shared by tappable elements across the
/// app, so buttons/tiles/icons animate consistently on click.
class AnimatedTapButton extends StatefulWidget {
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Widget child;

  const AnimatedTapButton({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<AnimatedTapButton> createState() => _AnimatedTapButtonState();
}

class _AnimatedTapButtonState extends State<AnimatedTapButton> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => _setPressed(true),
      onTapUp: disabled ? null : (_) => _setPressed(false),
      onTapCancel: disabled ? null : () => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: Duration(milliseconds: _isPressed ? 80 : 200),
        curve: _isPressed ? Curves.easeOut : Curves.easeOutBack,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
