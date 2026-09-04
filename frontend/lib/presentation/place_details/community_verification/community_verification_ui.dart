import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/hidden_place/hidden_place_provider.dart';
import '../../../widgets/app_feedback.dart';
import 'place_report_sheet.dart';

enum CommunityPlaceStatus {
  verified,
  unverified,
}

enum CommunityUserVote {
  none,
  verify,
}

/// Navigation payload for routing to [CommunityVerificationUI] through GoRouter.
class CommunityVerificationArgs {
  final String placeId;
  final CommunityPlaceStatus placeStatus;
  final CommunityUserVote userVote;
  final String placeName;
  final String recommendedBy;
  final int reportCount;
  final bool isReportedClosed;
  final bool hasReported;
  const CommunityVerificationArgs({
    required this.placeId,
    this.placeStatus = CommunityPlaceStatus.unverified,
    this.userVote = CommunityUserVote.none,
    this.placeName = '',
    this.recommendedBy = '',
    this.reportCount = 0,
    this.isReportedClosed = false,
    this.hasReported = false,
  });
}

/// Community verification screen for a RECOMMENDED PLACE.
///
/// Shows:
/// - verification state (verify / withdraw via recommended_place_verifications) — this IS a toggle
/// - place-report state (ONE-TIME per user + place in hidden_place_suppression; the report count is
///   never displayed — only the REPORTED_CLOSED suppression banner is shown)
///
/// The [placeId] is the recommended-place SUBMISSION id — the same value
/// used by the existing verify/withdraw API. It is NOT the Google place_id.
class CommunityVerificationUI extends StatefulWidget {
  final CommunityPlaceStatus placeStatus;
  final CommunityUserVote userVote;
  final String placeName;
  final String recommendedBy;

  /// Recommended-place submission id passed to the existing
  /// [HiddenPlaceProvider.castVote] verify/withdraw function and to
  /// the place-report API.
  final String placeId;

  /// Aggregate place-report count (from hidden_place_suppression).
  /// Kept for internal state compatibility; never rendered in the UI.
  final int reportCount;

  /// Whether the place has been moved to REPORTED_CLOSED (hidden after
  /// reaching the report threshold). When true, voting is disabled and a
  /// suppression banner is shown.
  final bool isReportedClosed;

  /// Whether the current user has ALREADY reported this place (persisted
  /// backend state). When true the Report Place card is disabled on first
  /// render — not just after an in-session report — so the non-clickable
  /// state survives leaving the screen and coming back (R10).
  final bool hasReported;

  const CommunityVerificationUI({
    super.key,
    required this.placeId,
    this.placeStatus = CommunityPlaceStatus.unverified,
    this.userVote = CommunityUserVote.none,
    this.placeName = '',
    this.recommendedBy = '',
    this.reportCount = 0,
    this.isReportedClosed = false,
    this.hasReported = false,
  });

  @override
  State<CommunityVerificationUI> createState() =>
      _CommunityVerificationUIState();
}

class _CommunityVerificationUIState
    extends State<CommunityVerificationUI> {
  static const Color accent = Color(0xffff6547);

  late CommunityUserVote _vote;
  late bool _isReportedClosed;
  bool _mutating = false;

  /// Whether the current user has already reported this place. Place Report is
  /// ONE-TIME per user + place (NOT a toggle), so after a successful report the
  /// Report Place card is disabled and no report-count is ever shown.
  bool _hasReported = false;

  @override
  void initState() {
    super.initState();
    // Temporary debug logging to verify correct identifier propagation.
    // COMMUNITY VERIFICATION DATA: the place_id / recommend_place_id /
    // submission_id as received. widget.placeId IS the submission id used by
    // the verify/withdraw and report APIs.
    debugPrint(
      'COMMUNITY VERIFICATION DATA: '
          'place_id=${widget.placeId}, '
          'recommend_place_id=${widget.placeId}, '
          'submission_id=${widget.placeId}, '
          'placeStatus=${widget.placeStatus.name}, '
          'userVote=${widget.userVote.name}',
    );
    _vote = widget.userVote;
    _isReportedClosed = widget.isReportedClosed;
    // Persisted backend state (R10): if the current user already reported
    // this place, the Report Place card is disabled from first render.
    _hasReported = widget.hasReported;
  }

  /// Aggregate community verification status.
  /// NOT the current user's own vote.
  bool get isVerified =>
      widget.placeStatus == CommunityPlaceStatus.verified;

  /// Routes the UI's Verify / Withdraw action to the EXISTING
  /// [HiddenPlaceProvider.castVote] function:
  ///   verify   -> castVote(placeId, isVerify: true)
  ///   withdraw -> castVote(placeId, isVerify: false)
  /// No HTTP / API / business logic lives in this file — the Provider owns it.
  Future<void> _castVote({required bool isVerify}) async {
    if (_mutating) return; // duplicate request prevention
    final placeId = widget.placeId;
    if (placeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submission selected.')),
      );
      return;
    }

    setState(() => _mutating = true);

    final provider = context.read<HiddenPlaceProvider>();
    final success = await provider.castVote(placeId, isVerify: isVerify);

    if (!mounted) return;
    setState(() => _mutating = false);

    if (success) {
      setState(() {
        _vote = isVerify
            ? CommunityUserVote.verify
            : CommunityUserVote.none;
      });
    }

    AppFeedback.show(
      context,
      message: success
          ? (isVerify
          ? 'Your verification was recorded.'
          : 'Your verification was withdrawn.')
          : provider.errorMessage ?? 'Failed to update your vote.',
      isSuccess: success,
    );
  }

  /// Opens the place-report sheet. On success marks the place as already
  /// reported by the current user (Place Report is ONE-TIME per user + place,
  /// so the Report Place card is disabled afterwards) and RETURNS to the parent
  /// Place Details screen. If the backend rejects the submission with a 409
  /// Conflict (same user already reported this place), the sheet closes without
  /// an error message, this screen flips to the already-reported (disabled)
  /// state, and it also returns to Place Details.
  ///
  /// The pop to Place Details happens ONLY after the report process finishes
  /// (success or duplicate 409). Opening the sheet, picking a reason, a failed
  /// report, a network error or a validation failure never pops.
  Future<void> _openPlaceReportSheet() async {
    if (_mutating) return;
    final result = await PlaceReportSheet.show(
      context,
      submissionId: widget.placeId,
    );
    if (!mounted) return;

    // Sheet closed without a response: if the backend said "already reported"
    // (409), reflect the persisted state (card becomes disabled), then pop.
    if (result == null) {
      if (context.read<HiddenPlaceProvider>().lastReportWasDuplicate) {
        setState(() => _hasReported = true);

        // Report process finished (duplicate report).
        // Return to the parent Place Details screen.
        Navigator.of(context).pop(context.mounted ? _vote : null);
      }
      return;
    }

    setState(() {
      _isReportedClosed = result.placeStatus == 'REPORTED_CLOSED';
      _hasReported = true;
    });
    AppFeedback.show(
      context,
      message: result.message,
      isSuccess: true,
    );

    // Report process finished successfully.
    // Return to the parent Place Details screen.
    Navigator.of(context).pop(_vote);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 14, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Community voting',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    // Return current user's vote so PlaceDetailUI can keep
                    // its local state synchronized after Verify/Withdraw.
                    onPressed: () => Navigator.pop(context, _vote),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(
                      Icons.close,
                      size: 25,
                      color: Color(0xff888888),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPlaceSection(),

                          const SizedBox(height: 24),

                          _buildInformationBox(),

                          const SizedBox(height: 28),

                          if (_isReportedClosed)
                            _buildSuppressionBanner()
                          else ...[
                            if (_mutating)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: LinearProgressIndicator(),
                              ),

                            if (_vote == CommunityUserVote.none)
                              _buildVotingSection()
                            else
                              _buildVotedSection(),
                            const SizedBox(height: 20),
                            // Place Report card — separate from community voting
                            _buildReportSection(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Always stays at the bottom of the full screen.
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 0, 22, 18),
                    child: Center(
                      child: Text(
                        'You can change your verification decision at any time',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xff888888),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.placeName,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.recommendedBy.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Recommended by ${widget.recommendedBy}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xff444444),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInformationBox() {
    final String message = isVerified
        ? 'Help us build a better travel community.\n'
        'This place has been verified by the community.'
        : 'Help us build a better travel community.\n'
        'Verify this place if it\'s worth visiting.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xfffff0e9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffeadbd4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.priority_high,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Suppression banner shown when the place has been moved to REPORTED_CLOSED.
  Widget _buildSuppressionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffff0e9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffe0c0b0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_off, color: accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Place hidden',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This place has been hidden after community reports.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xff555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What would you like to do?',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        if (!isVerified) ...[
          _actionCard(
            icon: Icons.check_rounded,
            iconColor: Colors.green,
            title: 'Verify Place',
            description:
            'This place exists and is worth recommending\nto other travelers.',
            onTap: _mutating
                ? null
                : () => _selectVote(CommunityUserVote.verify),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildVotedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: double.infinity),
        const Text(
          'You already voted for this place.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'You can change your decision below.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Color(0xff888888),
          ),
        ),
        const SizedBox(height: 18),
        _actionCard(
          icon: Icons.undo_rounded,
          iconColor: accent,
          title: 'Withdraw Verification',
          description: '',
          onTap: _mutating ? null : _withdrawVote,
        ),
      ],
    );
  }

  /// "Report Place" card — separate from voting, opens the place-report bottom
  /// sheet. Place Report is ONE-TIME per user + place (NOT a toggle), so no
  /// report count is ever displayed and the card is disabled once the current
  /// user has successfully reported this place.
  Widget _buildReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _actionCard(
          icon: Icons.report_problem_outlined,
          iconColor: accent,
          title: _hasReported ? 'Reported' : 'Report Place',
          description: _hasReported
              ? 'You have already reported this place.'
              : 'Let us know if this place has incorrect information.',
          onTap: (_mutating || _hasReported) ? null : _openPlaceReportSheet,
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1.0,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              minHeight: 82,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: const Color(0xfff3f3f3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xffdddddd),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.3,
                            color: Color(0xff555555),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 28,
                    color: Color(0xff222222),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectVote(CommunityUserVote vote) {
    // Verify is wired to the existing Provider verify function.
    if (vote == CommunityUserVote.verify) {
      _castVote(isVerify: true);
      return;
    }
  }

  void _withdrawVote() {
    // Withdrawing a verification is wired to the existing Provider withdraw
    // function (castVote with isVerify: false).
    _castVote(isVerify: false);
  }
}
