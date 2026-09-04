import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/community/community_model.dart';

const Color _kOrange = Color(0xFFFF7148);
const Color _kTitleDark = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF94A3B8);

/// "Community Browse - Overlay" bottom sheet: name, member count,
/// description, latest messages preview, and a Join Chat button.
class CommunityDetailsUi extends StatelessWidget {
  const CommunityDetailsUi({super.key, required this.community, required this.onJoin});

  final CommunityDetail community;
  final Future<void> Function() onJoin;

  static Future<void> show(
    BuildContext context, {
    required CommunityDetail community,
    required Future<void> Function() onJoin,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CommunityDetailsUi(community: community, onJoin: onJoin),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(community.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: _kTitleDark)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            Text('${community.memberCount} members', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kMuted)),
            const SizedBox(height: 12),
            if (community.description != null)
              Text(community.description!, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kTitleDark)),
            const SizedBox(height: 16),
            Text('LATEST MESSAGES',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Expanded(
              child: community.latestMessages.isEmpty
                  ? const Center(child: Text('No messages yet.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: community.latestMessages.length,
                      itemBuilder: (context, index) {
                        final m = community.latestMessages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundImage:
                                    m.senderProfilePictureUrl != null ? NetworkImage(m.senderProfilePictureUrl!) : null,
                                child: m.senderProfilePictureUrl == null
                                    ? Text(m.senderUsername.isEmpty ? '?' : m.senderUsername.characters.first)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.senderUsername, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                                    Text(m.content ?? '[media]', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: community.isJoined ? null : onJoin,
                child: Text(
                  community.isJoined ? 'Already Joined' : 'Join Chat',
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
