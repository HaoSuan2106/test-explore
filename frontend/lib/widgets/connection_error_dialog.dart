import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utilities/error_message.dart';

const Color _kPrimaryOrange = Color(0xFFFF7148);
const Color _kTitleDark = Color(0xFF101C2C);
const Color _kMuted = Color(0xFF64748B);
const Color _kIconBg = Color(0x1AFF7148);

/// The one panel the whole app shows when the backend cannot be reached.
///
/// Returns true if the user chose Retry, false if they dismissed it.
/// [HttpClient.onConnectionError] is wired to this in main.dart, so it covers
/// every backend call rather than being raised screen by screen — and the
/// user never sees a DioException or a stack trace.
///
/// Deliberately not dismissable by tapping outside or by the system back
/// button: the request that raised it is parked waiting on the answer, so it
/// needs a real choice.
Future<bool> showConnectionErrorDialog(BuildContext context) async {
  final chose = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _kIconBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: _kPrimaryOrange,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Error',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _kTitleDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              kConnectionErrorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 20 / 14,
                color: _kMuted,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(
                    'Dismiss',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimaryOrange,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    'Retry',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // A null result would mean the route went away under us (the screen was
  // disposed); treat that as "don't retry" rather than looping forever.
  return chose ?? false;
}
