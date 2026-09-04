import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/community/community_model.dart';

const Color _kTitleDark = Color(0xFF0F172A);

/// "View Participant List" bottom sheet.
class ParticipantListUi extends StatelessWidget {
  const ParticipantListUi({super.key, required this.participants});

  final List<ParticipantModel> participants;

  static void show(BuildContext context, List<ParticipantModel> participants) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ParticipantListUi(participants: participants),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...participants]
      ..sort((a, b) {
        if (a.role != b.role) return a.role == 'Moderator' ? -1 : 1;
        return a.username.compareTo(b.username);
      });

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Participants (${participants.length})',
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: _kTitleDark)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final p = sorted[index];
                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundImage: p.profilePictureUrl != null ? NetworkImage(p.profilePictureUrl!) : null,
                        child: p.profilePictureUrl == null
                            ? Text(p.username.isEmpty ? '?' : p.username.characters.first)
                            : null,
                      ),
                      if (p.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(p.username, style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                  trailing: p.role == 'Moderator'
                      ? const Chip(label: Text('Moderator', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
