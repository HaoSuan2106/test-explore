import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../api_communication/http_client/http_client.dart';
import '../../api_communication/signalr_client/signalr_client.dart';
import '../../models/community/community_model.dart';
import '../../models/community/message_model.dart';
import '../../utilities/error_message.dart';

/// Covers: View Community List, Join Community Group, Search Messages, Send
/// and Receive Messages, Reply Messages, View Participant List, Share Media.
class CommunicationProvider extends ChangeNotifier {
  CommunicationProvider({required HttpClient httpClient, required SignalrClient signalrClient})
      : _httpClient = httpClient,
        _signalrClient = signalrClient;

  final HttpClient _httpClient;
  final SignalrClient _signalrClient;

  List<CommunitySummary> joinedCommunities = [];
  List<CommunitySummary> browseResults = [];
  bool isLoading = false;
  String? errorMessage;

  /// Malaysia's 13 states plus the federal territories, for the state filter
  /// dropdown. Matches the "area"/"state" values used by the district-based
  /// seed data (InsertCommunityData_AllDistricts.sql).
  static const List<String> malaysianStates = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Perak',
    'Perlis',
    'Pulau Pinang',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'Federal Territories',
  ];

  int? _activeCommunityId;
  List<MessageModel> messages = [];
  List<ParticipantModel> participants = [];
  List<MessageModel> searchResults = [];
  bool isSearching = false;
  MessageModel? replyTarget;

  /// Fetches the communities the current user has already joined
  /// ("Community Explore" tab / View Community List).
  Future<void> loadJoinedCommunities() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      joinedCommunities = await _httpClient.getJoinedCommunities();
    } on DioException {
      errorMessage = 'Failed to load your communities.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Searches discoverable communities ("Browse Community" tab). The caller
  /// (the Browse screen) owns both the typed keyword and the selected state
  /// filter as its own widget state and passes both on every call, so a
  /// change to either one doesn't need to know or guess the other's current
  /// value.
  Future<void> browseCommunities({String? keyword, String? state}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      browseResults = await _httpClient.browseCommunities(keyword: keyword, state: state);
    } on DioException {
      errorMessage = 'Failed to browse communities.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<CommunityDetail?> getCommunityDetail(int communityId) async {
    try {
      return await _httpClient.getCommunityDetail(communityId);
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Failed to load community.';
      notifyListeners();
      return null;
    }
  }

  /// "Join Chat" button on the Community Browse overlay.
  Future<bool> joinCommunity(int communityId) async {
    try {
      final success = await _httpClient.joinCommunity(communityId);
      if (success) {
        await loadJoinedCommunities();
      }
      return success;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Failed to join community.';
      notifyListeners();
      return false;
    }
  }

  Future<String?> leaveCommunity(int communityId) async {
    try {
      final message = await _httpClient.leaveCommunity(communityId);
      joinedCommunities = joinedCommunities.where((c) => c.communityId != communityId).toList();
      notifyListeners();
      return message;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Failed to leave community.';
      notifyListeners();
      return null;
    }
  }

  /// Opens a community's chat room: connects the SignalR hub, joins its
  /// group, and loads message history + participants + presence updates.
  Future<void> openChatRoom(int communityId) async {
    _activeCommunityId = communityId;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _signalrClient.connect();
      await _signalrClient.joinCommunityGroup(communityId);

      _signalrClient.onMessageReceived.listen(_handleIncomingMessage);
      _signalrClient.onMessageDeleted.listen(_handleMessageDeleted);
      _signalrClient.onPresenceChanged.listen(_handlePresenceChanged);

      messages = await _httpClient.getMessages(communityId);
      participants = await _httpClient.getParticipants(communityId);
    } on DioException {
      errorMessage = 'Failed to open the chat room.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> closeChatRoom() async {
    if (_activeCommunityId != null) {
      await _signalrClient.leaveCommunityGroup(_activeCommunityId!);
    }
    _activeCommunityId = null;
    messages = [];
    participants = [];
    replyTarget = null;
    isSearching = false;
    searchResults = [];
  }

  /// True while an older-messages fetch is in flight. The chat screen's
  /// scroll listener fires on every notification at minScrollExtent, so this
  /// guard prevents a burst of duplicate "load older" requests for the same
  /// page (same beforeMessageId).
  bool _isLoadingOlder = false;
  bool get isLoadingOlder => _isLoadingOlder;

  Future<void> loadOlderMessages() async {
    if (_activeCommunityId == null || messages.isEmpty) return;
    if (_isLoadingOlder) return; // duplicate-request guard
    _isLoadingOlder = true;
    try {
      final older = await _httpClient.getMessages(_activeCommunityId!, beforeMessageId: messages.first.messageId);
      if (older.isEmpty) return;
      messages = [...older, ...messages];
      notifyListeners();
    } finally {
      _isLoadingOlder = false;
    }
  }

  void setReplyTarget(MessageModel? message) {
    replyTarget = message;
    notifyListeners();
  }

  /// Send and Receive Messages / Reply Messages / Share Media.
  Future<bool> sendMessage(String text, {List<String>? imageUrls, List<SharedPlaceRequest>? sharedPlaces}) async {
    if (_activeCommunityId == null) return false;
    final content = text.trim();
    if (content.isEmpty && (imageUrls?.isEmpty ?? true) && (sharedPlaces?.isEmpty ?? true)) return false;

    try {
      final sent = await _httpClient.sendMessage(SendMessageRequest(
        communityId: _activeCommunityId!,
        content: content.isEmpty ? null : content,
        replyToMessageId: replyTarget?.messageId,
        imageUrls: imageUrls,
        sharedPlaces: sharedPlaces,
      ));
      if (!messages.any((m) => m.messageId == sent.messageId)) {
        messages = [...messages, sent];
      }
      replyTarget = null;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Failed to send message.';
      notifyListeners();
      return false;
    }
  }

  /// Share Location: sends a PlaceShare message to [communityId], independent
  /// of whichever chat room (if any) is currently open — unlike [sendMessage],
  /// this doesn't require the target community's chat room to be the active
  /// one, since it's invoked from Place Details rather than from inside a
  /// chat room.
  Future<bool> shareLocationToCommunity(int communityId, SharedPlaceRequest place) async {
    try {
      final sent = await _httpClient.sendMessage(SendMessageRequest(
        communityId: communityId,
        sharedPlaces: [place],
      ));
      if (communityId == _activeCommunityId && !messages.any((m) => m.messageId == sent.messageId)) {
        messages = [...messages, sent];
        notifyListeners();
      }
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Failed to share this location.';
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadMessageImage(File file) async {
    if (_activeCommunityId == null) return null;
    try {
      return await _httpClient.uploadMessageImage(_activeCommunityId!, file);
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Failed to upload image.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteMessage(int messageId) async {
    try {
      await _httpClient.deleteMessage(messageId);
      messages = messages.where((m) => m.messageId != messageId).toList();
      notifyListeners();
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Failed to delete message.';
      notifyListeners();
      return false;
    }
  }

  /// Flags a message for moderation review. Idempotent on the backend, so
  /// reporting the same message twice is harmless.
  Future<bool> reportMessage(int messageId, {String? reason}) async {
    try {
      await _httpClient.reportMessage(messageId, reason: reason);
      return true;
    } on DioException catch (e) {
      errorMessage = messageForError(e) ?? 'Failed to report message.';
      notifyListeners();
      return false;
    }
  }

  /// Search Messages within the open chat room.
  Future<void> searchMessages(String keyword) async {
    if (_activeCommunityId == null) return;
    if (keyword.trim().isEmpty) {
      isSearching = false;
      searchResults = [];
      notifyListeners();
      return;
    }
    isSearching = true;
    searchResults = await _httpClient.searchMessages(_activeCommunityId!, keyword.trim());
    notifyListeners();
  }

  void clearSearch() {
    isSearching = false;
    searchResults = [];
    notifyListeners();
  }

  void _handleIncomingMessage(MessageModel message) {
    if (message.communityId != _activeCommunityId) return;
    if (messages.any((m) => m.messageId == message.messageId)) return;
    messages = [...messages, message];
    notifyListeners();
  }

  void _handleMessageDeleted(int messageId) {
    messages = messages.where((m) => m.messageId != messageId).toList();
    notifyListeners();
  }

  void _handlePresenceChanged(ParticipantPresenceEvent event) {
    if (event.communityId != _activeCommunityId) return;
    participants = participants
        .map((p) => p.userId == event.userId ? p.copyWith(isOnline: event.isOnline) : p)
        .toList();
    notifyListeners();
  }
}
