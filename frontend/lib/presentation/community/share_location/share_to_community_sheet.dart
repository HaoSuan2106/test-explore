import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/community/message_model.dart';
import '../../../providers/community/communication_provider.dart';
import '../../hidden_place_discovery/hidden_place_discovery_ui.dart' show PlaceData;

const Color _kOrange = Color(0xFFFF7148);
const Color _kTitleDark = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF94A3B8);

/// Builds the wire-format request for sharing [place] into a chat, from
/// whatever PlaceDetailUI happened to be showing (Google-sourced or a
/// community recommendation) — see MessageAttachment's PlaceLatitude/
/// PlaceLongitude/PlacePrimaryType/IsCommunityPlace snapshot fields.
SharedPlaceRequest _toSharedPlaceRequest(PlaceData place) {
  return SharedPlaceRequest(
    placeId: place.placeId,
    placeName: place.title,
    placeAddress: place.address,
    placeImageUrl: place.imageUrl.isEmpty ? null : place.imageUrl,
    placeStatus: place.businessStatus,
    placeLatitude: place.position.latitude,
    placeLongitude: place.position.longitude,
    placePrimaryType: place.primaryType,
    isCommunityPlace: place.recommendPlaceId != null,
  );
}

/// "Share" action on Place Details: pick one of the user's joined communities
/// and send this place into that group's chat as a PlaceShare message.
class ShareToCommunitySheet extends StatefulWidget {
  const ShareToCommunitySheet({super.key, required this.place});

  final PlaceData place;

  static Future<void> show(BuildContext context, {required PlaceData place}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ShareToCommunitySheet(place: place),
    );
  }

  @override
  State<ShareToCommunitySheet> createState() => _ShareToCommunitySheetState();
}

class _ShareToCommunitySheetState extends State<ShareToCommunitySheet> {
  int? _sendingToCommunityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunicationProvider>().loadJoinedCommunities();
    });
  }

  Future<void> _shareTo(int communityId, String communityName) async {
    if (_sendingToCommunityId != null) return;
    setState(() => _sendingToCommunityId = communityId);

    final provider = context.read<CommunicationProvider>();
    final success = await provider.shareLocationToCommunity(
      communityId,
      _toSharedPlaceRequest(widget.place),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Shared to $communityName.' : (provider.errorMessage ?? 'Failed to share this location.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunicationProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Share to Community',
                    style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: _kTitleDark)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(widget.place.title,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: _kOrange))
                : provider.joinedCommunities.isEmpty
                    ? Center(
                        child: Text(
                          "You haven't joined any communities yet.",
                          style: GoogleFonts.plusJakartaSans(color: _kMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: provider.joinedCommunities.length,
                        itemBuilder: (context, index) {
                          final community = provider.joinedCommunities[index];
                          final isSending = _sendingToCommunityId == community.communityId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _kOrange.withValues(alpha: 0.12),
                              backgroundImage: community.imageUrl != null ? NetworkImage(community.imageUrl!) : null,
                              child: community.imageUrl == null ? const Icon(Icons.groups_rounded, color: _kOrange) : null,
                            ),
                            title: Text(community.name, style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                            trailing: isSending
                                ? const SizedBox(
                                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_rounded, color: _kOrange, size: 18),
                            enabled: _sendingToCommunityId == null,
                            onTap: () => _shareTo(community.communityId, community.name),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
