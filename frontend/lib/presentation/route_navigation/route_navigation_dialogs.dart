import 'package:flutter/material.dart';

/// Dialogs for UC201 - Navigate to Hidden Place.
/// Each function shows the matching dialog and returns a Future you can
/// await to know which button was tapped, ready to wire into real
/// GPS/Google Routes API logic later.

const _accentColor = Color(0xFFF15A29);

/// A1: User Cancels Navigation -> M6
/// Resolves true if the user confirms cancellation.
Future<bool?> showCancelNavigationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ActionDialog(
      title: 'Cancel navigation',
      message: 'Are you sure you want to cancel navigation?',
      actions: [
        _DialogButton(label: 'No', filled: false, onTap: () => Navigator.of(context).pop(false)),
        _DialogButton(label: 'Yes, cancel', filled: true, onTap: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
}

/// A6: User Deviates from Route -> M5
/// Resolves true if the user chooses Recalculate.
Future<bool?> showRouteDeviationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.map_outlined,
      title: 'Off suggested route',
      message: 'Recalculate your route?',
      actions: [
        _DialogButton(label: 'Nevermind', filled: false, onTap: () => Navigator.of(context).pop(false)),
        _DialogButton(label: 'Recalculate', filled: true, onTap: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
}

/// A2: GPS Signal Unavailable -> M2
/// Resolves true if the user chooses Retry.
Future<bool?> showGpsUnavailableDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.gps_off,
      title: 'GPS signal unavailable',
      message: 'Move to an open area to continue.',
      stackedActions: true,
      actions: [
        _DialogButton(label: 'Retry', filled: true, onTap: () => Navigator.of(context).pop(true)),
        _DialogButton(label: 'Cancel navigation', filled: false, onTap: () => Navigator.of(context).pop(false)),
      ],
    ),
  );
}

/// A8: User Already at Destination -> M9
Future<void> showAlreadyAtDestinationDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.location_on,
      title: "You're already here",
      message: 'Your visit has been recorded.',
      actions: [
        _DialogButton(label: 'OK', filled: true, onTap: () => Navigator.of(context).pop()),
      ],
    ),
  );
}

/// Successful arrival -> M1
Future<void> showArrivalSuccessDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ActionDialog(
      title: 'Congrats \u{1F389}\u{1F389}\u{1F389}',
      message: 'Successful arrived destination',
      actions: [
        _DialogButton(label: 'OK', filled: true, onTap: () => Navigator.of(context).pop()),
      ],
    ),
  );
}

/// A4: Location Permission Denied -> M3
Future<void> showLocationPermissionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.location_disabled,
      title: 'Location permission required',
      message: 'Please enable location permission and try again.',
      actions: [
        _DialogButton(label: 'OK', filled: true, onTap: () => Navigator.of(context).pop()),
      ],
    ),
  );
}

/// A5: Route Request Failed -> M4
/// Resolves true if the user chooses Retry.
Future<bool?> showRouteRequestFailedDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.error_outline,
      title: 'Unable to generate route',
      message: 'Please check your Internet connection and try again.',
      stackedActions: true,
      actions: [
        _DialogButton(label: 'Retry', filled: true, onTap: () => Navigator.of(context).pop(true)),
        _DialogButton(label: 'Cancel navigation', filled: false, onTap: () => Navigator.of(context).pop(false)),
      ],
    ),
  );
}

/// Manual recalculate — user pressed the Recalculate button on the map
/// (not the automatic deviation prompt). Reuses the same dialog styling.
/// Resolves true if the user confirms.
Future<bool?> showRecalculateRouteConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.alt_route,
      title: 'Recalculate route',
      message: 'Get a new route from your current location?',
      actions: [
        _DialogButton(label: 'Cancel', filled: false, onTap: () => Navigator.of(context).pop(false)),
        _DialogButton(label: 'Recalculate', filled: true, onTap: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
}

class _ActionDialog extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String message;
  final List<_DialogButton> actions;
  final bool stackedActions;

  const _ActionDialog({
    this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.stackedActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 32, color: _accentColor),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            if (stackedActions)
              Column(
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    SizedBox(width: double.infinity, child: actions[i]),
                    if (i != actions.length - 1) const SizedBox(height: 10),
                  ],
                ],
              )
            else
              Row(
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    Expanded(child: actions[i]),
                    if (i != actions.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _DialogButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}