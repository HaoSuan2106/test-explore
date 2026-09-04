import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../http_client/http_client.dart';
import '../secure_storage/secure_storage_service.dart';
import '../../models/community/message_model.dart';

class ParticipantPresenceEvent {
  const ParticipantPresenceEvent({required this.communityId, required this.userId, required this.isOnline});

  final int communityId;
  final int userId;
  final bool isOnline;
}

/// Wraps the SignalR connection to CommunityChatHub (`/hubs/community-chat`)
/// for real-time Send/Receive Messages and presence, on top of the message
/// history that comes from HttpClient's REST endpoints.
class SignalrClient {
  SignalrClient({required SecureStorageService secureStorage}) : _secureStorage = secureStorage;

  final SecureStorageService _secureStorage;
  HubConnection? _connection;

  final _messageController = StreamController<MessageModel>.broadcast();
  final _messageDeletedController = StreamController<int>.broadcast();
  final _presenceController = StreamController<ParticipantPresenceEvent>.broadcast();

  Stream<MessageModel> get onMessageReceived => _messageController.stream;
  Stream<int> get onMessageDeleted => _messageDeletedController.stream;
  Stream<ParticipantPresenceEvent> get onPresenceChanged => _presenceController.stream;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> connect() async {
    if (isConnected) return;

    _connection = HubConnectionBuilder()
        .withUrl(
          '${HttpClient.baseUrl}/hubs/community-chat',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => (await _secureStorage.getAccessToken()) ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('ReceiveMessage', (args) {
      if (args == null || args.isEmpty) return;
      _messageController.add(MessageModel.fromJson(Map<String, dynamic>.from(args[0] as Map)));
    });

    _connection!.on('MessageDeleted', (args) {
      if (args == null || args.length < 2) return;
      _messageDeletedController.add(args[1] as int);
    });

    _connection!.on('ParticipantOnlineStatusChanged', (args) {
      if (args == null || args.length < 3) return;
      _presenceController.add(ParticipantPresenceEvent(
        communityId: args[0] as int,
        userId: args[1] as int,
        isOnline: args[2] as bool,
      ));
    });

    await _connection!.start();
  }

  Future<void> joinCommunityGroup(int communityId) async {
    await _connection?.invoke('JoinCommunityGroup', args: [communityId]);
  }

  Future<void> leaveCommunityGroup(int communityId) async {
    await _connection?.invoke('LeaveCommunityGroup', args: [communityId]);
  }

  Future<void> notifyTyping(int communityId, bool isTyping) async {
    await _connection?.invoke('NotifyTyping', args: [communityId, isTyping]);
  }

  Future<void> disconnect() async {
    await _connection?.stop();
  }
}
