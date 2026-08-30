import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/community/community_model.dart';
import '../../../models/community/message_model.dart';
import '../../../providers/community/communication_provider.dart';

const Color _kOrange = Color(0xFFFF7148);
const Color _kTitleDark = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF94A3B8);

/// Opens the "Share to Chat" bottom sheet: lets the user pick one of their
/// joined communities and sends [sharedPlace] or [sharedPost] into that
/// chat as a message. Reused by Hidden Place Discovery's place-detail Share
/// button and Post Review's feed-card/post-detail Share buttons — exactly
/// one of [sharedPlace] / [sharedPost] should be provided.
Future<void> showShareToChatSheet(
  BuildContext context, {
  SharedPlaceRequest? sharedPlace,
  SharedPostRequest? sharedPost,
}) {
  assert(
    (sharedPlace == null) != (sharedPost == null),
    'showShareToChatSheet needs exactly one of sharedPlace or sharedPost.',
  );
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareToChatSheet(sharedPlace: sharedPlace, sharedPost: sharedPost),
  );
}

class _ShareToChatSheet extends StatefulWidget {
  const _ShareToChatSheet({this.sharedPlace, this.sharedPost});

  final SharedPlaceRequest? sharedPlace;
  final SharedPostRequest? sharedPost;

  @override
  State<_ShareToChatSheet> createState() => _ShareToChatSheetState();
}

class _ShareToChatSheetState extends State<_ShareToChatSheet> {
  bool _isLoading = true;
  int? _sendingToId;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    final provider = context.read<CommunicationProvider>();
    if (provider.joinedCommunities.isEmpty) {
      await provider.loadJoinedCommunities();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendTo(CommunitySummary community) async {
    setState(() => _sendingToId = community.communityId);
    final provider = context.read<CommunicationProvider>();
    final success = await provider.shareToChat(
      community.communityId,
      sharedPlaces: widget.sharedPlace == null ? null : [widget.sharedPlace!],
      sharedPosts: widget.sharedPost == null ? null : [widget.sharedPost!],
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Shared to ${community.name}.' : 'Failed to share. Please try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final communities = context.watch<CommunicationProvider>().joinedCommunities;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Text('Share to Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kTitleDark)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: _kOrange)))
                  : communities.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            "You haven't joined any communities yet.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _kMuted),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: communities.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                          itemBuilder: (_, i) {
                            final community = communities[i];
                            final isSending = _sendingToId == community.communityId;
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFF1F5F9),
                                backgroundImage: community.imageUrl != null ? NetworkImage(community.imageUrl!) : null,
                                child: community.imageUrl == null
                                    ? const Icon(Icons.groups_rounded, color: _kOrange)
                                    : null,
                              ),
                              title: Text(community.name, style: const TextStyle(fontWeight: FontWeight.w600, color: _kTitleDark)),
                              subtitle: [community.state, community.area].where((s) => s != null && s.isNotEmpty).isEmpty
                                  ? null
                                  : Text([community.state, community.area].where((s) => s != null && s.isNotEmpty).join(' • ')),
                              trailing: isSending
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _kOrange))
                                  : null,
                              onTap: _sendingToId != null ? null : () => _sendTo(community),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
