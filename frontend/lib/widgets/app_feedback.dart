import 'dart:async';
import 'package:flutter/material.dart';

/// Shared toast feedback — the approved solid-color toast implementation.
///
/// Renders the approved Solid Green Success / Solid Red Error toast:
///
/// 🟢 SUCCESS — solid dark green `0xFF2E7D32`, white `check_circle` icon
/// 🔴 ERROR   — solid dark red   `0xFFD32F2F`, white `error` icon
///
/// Layout per spec:
/// - full-width container, padding h16 / v14
/// - radius 8, soft drop shadow
/// - white 14px w600 message text next to a 22px icon
///
/// The toast is presented through the root [Overlay] (top of screen, below
/// the safe area / app bar) so it works from any context — screens, dialogs
/// and bottom sheets — and auto-dismisses after 3 seconds.
///
/// Only ONE toast is shown at a time: a new [show] call removes any toast
/// currently on screen instead of stacking broken messages.
class AppFeedback {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  /// Shows the approved toast with the given [message].
  ///
  /// Set [isSuccess] to `true` (default) for the Solid Green Success toast,
  /// or `false` for the Solid Red Error toast.
  static void show(
    BuildContext context, {
    required String message,
    bool isSuccess = true,
  }) {
    _removeActive();

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastHost(
        isSuccess: isSuccess,
        message: message,
        onDismiss: () => _remove(entry),
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(const Duration(seconds: 3), () {
      _remove(entry);
    });
  }

  static void _removeActive() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    final entry = _activeEntry;
    _activeEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }

  static void _remove(OverlayEntry entry) {
    if (!identical(_activeEntry, entry)) return;
    _removeActive();
  }
}

/// Positions the approved toast at the top of the screen (below the safe
/// area) and ignores pointer events so it never blocks taps.
class _ToastHost extends StatelessWidget {
  final bool isSuccess;
  final String message;
  final VoidCallback onDismiss;

  const _ToastHost({
    required this.isSuccess,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topPadding + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildToast(isSuccess ? 'Success' : 'Error'),
        ),
      ),
    );
  }

  /// Solid Green Success toast (0xFF2E7D32 + check_circle).
  Widget _buildSuccessToast(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32), // Solid Dark Green
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                // Explicitly disable any inherited text decoration (the
                // approved toast has plain white text — no underline, no
                // hyperlink styling from global typography / text themes).
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Solid Red Error toast (0xFFD32F2F + error icon).
  Widget _buildErrorToast(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F), // Solid Dark Red
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                // Explicitly disable any inherited text decoration — the
                // approved error toast is plain white text with no underline.
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToast(String _) =>
      isSuccess ? _buildSuccessToast(message) : _buildErrorToast(message);
}
