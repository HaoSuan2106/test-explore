import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/hidden_place/recommended_place_model.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';
import '../../../utilities/place_report_reasons.dart';
import '../../../widgets/app_feedback.dart';

/// Bottom sheet for PLACE reporting (ONE-TIME per user + place — NOT a toggle).
///
/// This is a SEPARATE sheet from the POST reporting sheet
/// (ReportReasonSheet). It targets PLACE reports only, which
/// go to hidden_place_suppression on the backend — never
/// community_post_reports.
///
/// Report reasons are SYSTEM-DEFINED fixed values
/// (PlaceReportReasons — mirrored from the backend's authoritative
/// PlaceReportReasons.All). There is NO admin management and NO runtime
/// fetch: the sheet renders the fixed list instantly, even offline. The
/// backend validates every submitted reason against its own list.
///
/// Returns [ReportPlaceResponse] on success via Navigator.pop,
/// so the caller can update isReportedClosed / reported state.
class PlaceReportSheet extends StatefulWidget {
  final String submissionId;

  const PlaceReportSheet({super.key, required this.submissionId});

  /// Shows the sheet and returns a [ReportPlaceResponse] or null.
  static Future<ReportPlaceResponse?> show(
    BuildContext context, {
    required String submissionId,
  }) {
    return showModalBottomSheet<ReportPlaceResponse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PlaceReportSheet(submissionId: submissionId),
    );
  }

  @override
  State<PlaceReportSheet> createState() => _PlaceReportSheetState();
}

class _PlaceReportSheetState extends State<PlaceReportSheet> {
  static const Color _accent = Color(0xffff6547);

  String? _selectedReason;
  bool _submitting = false;

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null || reason.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    final provider = context.read<HiddenPlaceProvider>();
    final result = await provider.reportPlace(
      widget.submissionId,
      reason,
    );
    if (!mounted) return;
    if (result == null) {
      // A 409 Conflict signals the report is already recorded for this user + place.
      // Close the sheet without a long error message — the parent reflects the
      // already-reported state (disabled card) via [lastReportWasDuplicate].
      if (provider.lastReportWasDuplicate) {
        Navigator.of(context).pop();
        return;
      }

      // Genuine network / server error: show a short friendly message and let the
      // user retry (the sheet stays open).
      final message = provider.errorMessage ?? 'Failed to submit report. Please try again.';
      AppFeedback.show(
        context,
        message: message,
        isSuccess: false,
      );
      setState(() => _submitting = false);
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Report Place',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xff222222)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'You can report each place only once. Why are you reporting this place?',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xff666666),
              ),
            ),
            const SizedBox(height: 16),
            ...PlaceReportReasons.uiSelectable.map((reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedReason = reason),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedReason == reason
                              ? _accent.withValues(alpha: 0.08)
                              : const Color(0xfff5f5f5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedReason == reason
                                ? _accent
                                : const Color(0xffdddddd),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedReason == reason
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: _selectedReason == reason
                                  ? _accent
                                  : const Color(0xff999999),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                PlaceReportReasons.friendlyLabel(reason),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedReason == null || _submitting
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xffcccccc),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
