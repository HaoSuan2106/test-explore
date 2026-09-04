import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/community/message_model.dart';
import '../../../providers/auth_profile/profile_provider.dart';
import '../../../providers/community/communication_provider.dart';
import '../../hidden_place_discovery/hidden_place_discovery_ui.dart' show PlaceData;
import '../../place_details/place_details_ui.dart';
import '../participant_list/participant_list_ui.dart';

const Color _kOrange = Color(0xFFFF7148);
const Color _kTitleDark = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF94A3B8);
const Color _kBubbleGrey = Color(0xFFF1F5F9);

/// The conversation screen for a single community — pushed from
/// [CommunityListUi]. Covers: Send and Receive Messages, Reply Messages,
/// Search Messages, View Participant List, Share Media.
class ChatRoomUi extends StatefulWidget {
  const ChatRoomUi({super.key, required this.communityId, required this.communityName});

  final int communityId;
  final String communityName;

  @override
  State<ChatRoomUi> createState() => _ChatRoomUiState();
}

class _ChatRoomUiState extends State<ChatRoomUi> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CommunicationProvider>().openChatRoom(widget.communityId);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSend() async {
    final provider = context.read<CommunicationProvider>();
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    final sent = await provider.sendMessage(text);
    if (sent) {
      _textController.clear();
      _scrollToBottom();
    } else {
      _showError(provider.errorMessage ?? 'Failed to send message.');
    }
  }

  Future<void> _handleShareImage() async {
    final provider = context.read<CommunicationProvider>();
    final XFile? picked;
    try {
      picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    } catch (e) {
      // Most commonly a missing gallery-access permission on Android <13, or no
      // gallery app available at all — image_picker throws a PlatformException.
      _showError('Could not open the gallery: $e');
      return;
    }
    if (picked == null) return; // user backed out of the picker — not an error

    final url = await provider.uploadMessageImage(File(picked.path));
    if (!mounted) return;
    if (url == null) {
      _showError(provider.errorMessage ?? 'Failed to upload image.');
      return;
    }

    final sent = await provider.sendMessage('', imageUrls: [url]);
    if (!sent && mounted) {
      _showError(provider.errorMessage ?? 'Image uploaded, but sending the message failed.');
    }
    _scrollToBottom();
  }

  Future<void> _handleLeaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this community?'),
        content: Text("You'll stop receiving messages from ${widget.communityName} until you rejoin."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<CommunicationProvider>();
    final result = await provider.leaveCommunity(widget.communityId);
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(); // back to the community list
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    } else {
      _showError(provider.errorMessage ?? 'Failed to leave the community.');
    }
  }

  /// Long-press action sheet: Reply for anyone, Report for anyone else's
  /// message, Delete for your own.
  void _showMessageActions(MessageModel message, bool isMine) {
    final provider = context.read<CommunicationProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: _kOrange),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                provider.setReplyTarget(message);
              },
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final deleted = await provider.deleteMessage(message.messageId);
                  if (!deleted) _showError(provider.errorMessage ?? 'Failed to delete message.');
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: const Text('Report', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final reported = await provider.reportMessage(message.messageId);
                  _showError(reported ? 'Message reported.' : (provider.errorMessage ?? 'Failed to report message.'));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunicationProvider>();
    // Read-only cross-module dependency: the Auth/Profile module already loads
    // and caches the signed-in user's profile at app startup, so this reuses
    // it to know which messages are "mine" instead of duplicating that state.
    final myUserId = context.watch<ProfileProvider>().profile?.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTitleDark,
        elevation: 0,
        titleSpacing: 0,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => context.read<CommunicationProvider>().searchMessages(value),
                decoration: const InputDecoration(hintText: 'Search messages...', border: InputBorder.none),
              )
            : Text(widget.communityName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                context.read<CommunicationProvider>().clearSearch();
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () => ParticipantListUi.show(context, provider.participants),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'leave') _handleLeaveGroup();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'leave',
                child: Text('Leave Group', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : Column(
              children: [
                Expanded(
                  child: provider.isSearching
                      ? _buildMessageList(provider, provider.searchResults, myUserId, scrollable: false)
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.pixels == notification.metrics.minScrollExtent) {
                              context.read<CommunicationProvider>().loadOlderMessages();
                            }
                            return false;
                          },
                          child: _buildMessageList(provider, provider.messages, myUserId, scrollable: true),
                        ),
                ),
                _buildComposer(provider),
              ],
            ),
    );
  }

  Widget _buildMessageList(
    CommunicationProvider provider,
    List<MessageModel> messages,
    int? myUserId, {
    required bool scrollable,
  }) {
    if (messages.isEmpty) {
      return Center(child: Text('No messages yet. Say hello!', style: GoogleFonts.plusJakartaSans(color: _kMuted)));
    }
    return ListView.builder(
      controller: scrollable ? _scrollController : null,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMine = myUserId != null && message.senderUserId == myUserId;
        return _MessageBubble(
          message: message,
          isMine: isMine,
          onLongPress: () => _showMessageActions(message, isMine),
        );
      },
    );
  }

  Widget _buildComposer(CommunicationProvider provider) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE4BEB7))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.replyTarget != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: _kOrange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Replying to ${provider.replyTarget!.senderUsername}: ${provider.replyTarget!.content ?? '[media]'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => provider.setReplyTarget(null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined, color: _kOrange),
                  onPressed: _handleShareImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 4,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: _kOrange),
                  onPressed: _handleSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    context.read<CommunicationProvider>().closeChatRoom();
    _scrollController.dispose();
    _searchController.dispose();
    _textController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine, required this.onLongPress});

  final MessageModel message;
  final bool isMine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? _kOrange : _kBubbleGrey;
    final textColor = isMine ? Colors.white : _kTitleDark;

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(message.senderUsername,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _kOrange)),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.replyToPreview != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: isMine ? Colors.white70 : _kOrange, width: 3)),
                      ),
                      child: Text(
                        message.replyToPreview!.content ?? '[media]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: isMine ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  if (message.content != null && message.content!.isNotEmpty)
                    Text(message.content!, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textColor)),
                  for (final attachment in message.attachments) _AttachmentView(attachment: attachment),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Only other people's messages show an avatar — matches the reference
    // design, and avoids cluttering the sender's own side of the thread with
    // their own face on every bubble.
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: isMine
            ? bubble
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _kOrange.withValues(alpha: 0.15),
                    backgroundImage:
                        message.senderProfilePictureUrl != null ? NetworkImage(message.senderProfilePictureUrl!) : null,
                    child: message.senderProfilePictureUrl == null
                        ? Text(
                            message.senderUsername.isEmpty ? '?' : message.senderUsername.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 11, color: _kOrange, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  bubble,
                ],
              ),
      ),
    );
  }
}

/// Reconstructs a lightweight [PlaceData] from a PlaceShare attachment's
/// share-time snapshot, so tapping it in chat reopens PlaceDetailUI without a
/// live re-fetch — same convention FavouritePlaceScreen/ExplorationHistory
/// already use for their own lighter-weight lists (rating/hours/photos left
/// at their PlaceData defaults; Direction/Save/Report/Community all still
/// work off placeId/position/primaryType/recommendPlaceId).
PlaceData _attachmentToPlaceData(MessageAttachmentModel attachment) {
  return PlaceData(
    placeId: attachment.placeId ?? '',
    title: attachment.placeName ?? 'Shared place',
    category: attachment.placePrimaryType ?? 'unknown',
    primaryType: attachment.placePrimaryType ?? 'unknown',
    imageUrl: attachment.placeImageUrl ?? '',
    icon: Icons.place,
    position: LatLng(attachment.placeLatitude ?? 0, attachment.placeLongitude ?? 0),
    rating: 0.0,
    ratingCount: 0,
    priceLevel: null,
    businessStatus: attachment.placeStatus ?? 'UNKNOWN',
    photoAttribution: null,
    recommendPlaceId: attachment.isCommunityPlace ? attachment.placeId : null,
    address: attachment.placeAddress,
    phoneNumber: null,
    websiteUri: null,
    googleMapsUri: null,
    photosJson: null,
    regularOpeningHoursJson: null,
  );
}

void _openSharedPlace(BuildContext context, MessageAttachmentModel attachment) {
  if (attachment.placeId == null) return;
  final place = _attachmentToPlaceData(attachment);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _SharedPlaceScreen(place: place),
  ));
}

/// Hosts [PlaceDetailUI] for a place tapped in chat. PlaceDetailUI is a sheet
/// designed to sit inside a Scaffold — every other caller either embeds it as
/// a Scaffold's body or, like PlaceDetailMapScreen ("a minimal map + place
/// detail sheet screen for opening a single known place"), gives it a
/// Scaffold + map of its own. Pushing it bare (no Scaffold) is what caused
/// the "No Material widget found" errors on the Overview/Reviews/Photos tabs
/// the first time this screen was opened from chat — it isn't a bug in
/// place_details_ui.dart itself. This mirrors PlaceDetailMapScreen's
/// structure locally instead of reusing it directly, only to also pass
/// reviewTargetType (needed so a shared community-recommended place's
/// reviews load correctly, which PlaceDetailMapScreen's call site doesn't
/// need for its own callers).
class _SharedPlaceScreen extends StatelessWidget {
  const _SharedPlaceScreen({required this.place});

  final PlaceData place;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: place.position, zoom: 16),
            markers: {
              Marker(markerId: MarkerId(place.placeId), position: place.position),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          PlaceDetailUI(
            place: place,
            onClose: () => Navigator.of(context).pop(),
            reviewTargetType: place.isCommunity ? PlaceReviewTargetType.system : PlaceReviewTargetType.google,
          ),
        ],
      ),
    );
  }
}

class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.attachment});

  final MessageAttachmentModel attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.type == 'Image' && attachment.mediaUrl != null) {
      final heroTag = 'attachment-${attachment.attachmentId}';
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _FullScreenImageView(imageUrl: attachment.mediaUrl!, heroTag: heroTag),
          )),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Hero(
              tag: heroTag,
              child: Image.network(attachment.mediaUrl!, fit: BoxFit.cover, height: 160, width: 220),
            ),
          ),
        ),
      );
    }

    if (attachment.type == 'PlaceShare') {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: () => _openSharedPlace(context, attachment),
          child: Container(
            width: 220,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attachment.placeImageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: Image.network(attachment.placeImageUrl!, height: 100, width: double.infinity, fit: BoxFit.cover),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(attachment.placeName ?? 'Shared place',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      if (attachment.placeAddress != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          attachment.placeAddress!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Full-screen viewer for a tapped Share Media image — pinch/drag to zoom,
/// and the standard AppBar back arrow (or system back gesture) returns to
/// the chat thread.
class _FullScreenImageView extends StatelessWidget {
  const _FullScreenImageView({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
