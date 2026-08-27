import 'package:flutter/material.dart';

enum CommunityPlaceStatus {
  verified,
  unverified,
}

enum CommunityUserVote {
  none,
  verify,
  report,
}

class CommunityVerificationUI extends StatefulWidget {
  final CommunityPlaceStatus placeStatus;
  final CommunityUserVote userVote;
  final String placeName;
  final String recommendedBy;
  final String? imageAsset;

  const CommunityVerificationUI({
    super.key,
    this.placeStatus = CommunityPlaceStatus.unverified,
    this.userVote = CommunityUserVote.none,
    this.placeName = 'Mantap Café',
    this.recommendedBy = 'Rikki',
    this.imageAsset,
  });

  @override
  State<CommunityVerificationUI> createState() =>
      _CommunityVerificationUIState();
}

class _CommunityVerificationUIState
    extends State<CommunityVerificationUI> {
  static const Color accent = Color(0xffff6547);

  late CommunityUserVote _vote;

  @override
  void initState() {
    super.initState();
    _vote = widget.userVote;
  }

  bool get isVerified =>
      widget.placeStatus == CommunityPlaceStatus.verified;

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
                    onPressed: () => Navigator.pop(context),
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

                          if (_vote == CommunityUserVote.none)
                            _buildVotingSection()
                          else
                            _buildVotedSection(),
                        ],
                      ),
                    ),
                  ),

                  // Always stays at the bottom of the full screen.
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 0, 22, 18),
                    child: Center(
                      child: Text(
                        'You can only vote once for each recommendation',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _placeImage(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.placeName,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Recommended by ${widget.recommendedBy}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff444444),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInformationBox() {
    final String message = isVerified
        ? 'Help us build a better travel community.\n'
        'Report it if the information is incorrect or not longer exist.'
        : 'Help us build a better travel community.\n'
        'Verify this place if it’s worth visiting or report it if '
        'the information is incorrect.';

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
            'This place exist and is worth recommending\nto other travelers.',
            onTap: () => _selectVote(CommunityUserVote.verify),
          ),
          const SizedBox(height: 12),
        ],

        _actionCard(
          icon: Icons.flag_rounded,
          iconColor: Colors.red,
          title: 'Report Place',
          description:
          'This place information is incorrect, closed,\nor not worth visiting',
          onTap: () => _selectVote(CommunityUserVote.report),
        ),
      ],
    );
  }

  Widget _buildVotedSection() {
    final bool votedVerify =
        _vote == CommunityUserVote.verify;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          title: votedVerify
              ? 'Withdraw Verification'
              : 'Withdraw Report',
          description: '',
          onTap: _withdrawVote,
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
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
              const Icon(
                Icons.chevron_right,
                size: 28,
                color: Color(0xff222222),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeImage() {
    if (widget.imageAsset != null &&
        widget.imageAsset!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          widget.imageAsset!,
          width: 164,
          height: 112,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imagePlaceholder(),
        ),
      );
    }

    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 164,
      height: 112,
      decoration: BoxDecoration(
        color: const Color(0xffdddddd),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Color(0xff999999),
          size: 34,
        ),
      ),
    );
  }

  void _selectVote(CommunityUserVote vote) {
    setState(() {
      _vote = vote;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vote == CommunityUserVote.verify
              ? 'Verify Place selected'
              : 'Report Place selected',
        ),
      ),
    );
  }

  void _withdrawVote() {
    final CommunityUserVote previousVote = _vote;

    setState(() {
      _vote = CommunityUserVote.none;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          previousVote == CommunityUserVote.verify
              ? 'Verification withdrawn'
              : 'Report withdrawn',
        ),
      ),
    );
  }
}
