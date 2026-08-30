class MessageAttachmentModel {
  const MessageAttachmentModel({
    required this.attachmentId,
    required this.type,
    this.mediaUrl,
    this.placeId,
    this.placeSource,
    this.shareDataJson,
    this.placeName,
    this.placeAddress,
    this.placeImageUrl,
    this.placeStatus,
    this.postId,
  });

  final int attachmentId;
  final String type; // 'Image' | 'PlaceShare' | 'PostShare'
  final String? mediaUrl;
  final String? placeId;
  final String? placeSource; // 'GOOGLE' | 'COMMUNITY'
  final String? shareDataJson;
  final String? placeName;
  final String? placeAddress;
  final String? placeImageUrl;
  final String? placeStatus;
  final String? postId;

  factory MessageAttachmentModel.fromJson(Map<String, dynamic> json) => MessageAttachmentModel(
    attachmentId: json['attachmentId'] as int,
    type: json['type'] as String,
    mediaUrl: json['mediaUrl'] as String?,
    placeId: json['placeId'] as String?,
    placeSource: json['placeSource'] as String?,
    shareDataJson: json['shareDataJson'] as String?,
    placeName: json['placeName'] as String?,
    placeAddress: json['placeAddress'] as String?,
    placeImageUrl: json['placeImageUrl'] as String?,
    placeStatus: json['placeStatus'] as String?,
    postId: json['postId'] as String?,
  );
}

class MessageModel {
  const MessageModel({
    required this.messageId,
    required this.communityId,
    required this.senderUserId,
    required this.senderUsername,
    this.senderProfilePictureUrl,
    this.content,
    required this.sentAt,
    this.replyToMessageId,
    this.replyToPreview,
    this.attachments = const [],
  });

  final int messageId;
  final int communityId;
  final int senderUserId;
  final String senderUsername;
  final String? senderProfilePictureUrl;
  final String? content;
  final DateTime sentAt;
  final int? replyToMessageId;
  final MessageModel? replyToPreview;
  final List<MessageAttachmentModel> attachments;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    messageId: json['messageId'] as int,
    communityId: json['communityId'] as int,
    senderUserId: json['senderUserId'] as int,
    senderUsername: json['senderUsername'] as String? ?? 'Unknown User',
    senderProfilePictureUrl: json['senderProfilePictureUrl'] as String?,
    content: json['content'] as String?,
    sentAt: DateTime.parse(json['sentAt'] as String),
    replyToMessageId: json['replyToMessageId'] as int?,
    replyToPreview: json['replyToPreview'] == null
        ? null
        : MessageModel.fromJson(json['replyToPreview'] as Map<String, dynamic>),
    attachments: (json['attachments'] as List<dynamic>? ?? [])
        .map((a) => MessageAttachmentModel.fromJson(a as Map<String, dynamic>))
        .toList(),
  );
}

class SharedPlaceRequest {
  const SharedPlaceRequest({
    required this.placeId,
    required this.placeSource,
    this.shareDataJson,
    required this.placeName,
    this.placeAddress,
    this.placeImageUrl,
    this.placeStatus,
  });

  /// Google place_id or a community submission/place id (string either way).
  final String placeId;
  /// 'GOOGLE' | 'COMMUNITY' — which detail screen a tap on this message should reopen.
  final String placeSource;
  /// Snapshot of the place (PlaceData, JSON-encoded) taken at share time.
  /// Required when [placeSource] is 'GOOGLE' (no live "fetch by id" route
  /// exists for Google-sourced places); left null for 'COMMUNITY', which
  /// reopens live instead.
  final String? shareDataJson;
  final String placeName;
  final String? placeAddress;
  final String? placeImageUrl;
  final String? placeStatus;

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'placeSource': placeSource,
    'shareDataJson': shareDataJson,
    'placeName': placeName,
    'placeAddress': placeAddress,
    'placeImageUrl': placeImageUrl,
    'placeStatus': placeStatus,
  };
}

class SharedPostRequest {
  const SharedPostRequest({
    required this.postId,
    required this.postTitle,
    this.postImageUrl,
    this.postLocation,
  });

  final String postId;
  final String postTitle;
  final String? postImageUrl;
  final String? postLocation;

  Map<String, dynamic> toJson() => {
    'postId': postId,
    'postTitle': postTitle,
    'postImageUrl': postImageUrl,
    'postLocation': postLocation,
  };
}

class SendMessageRequest {
  const SendMessageRequest({
    required this.communityId,
    this.content,
    this.replyToMessageId,
    this.imageUrls,
    this.sharedPlaces,
    this.sharedPosts,
  });

  final int communityId;
  final String? content;
  final int? replyToMessageId;
  final List<String>? imageUrls;
  final List<SharedPlaceRequest>? sharedPlaces;
  final List<SharedPostRequest>? sharedPosts;

  Map<String, dynamic> toJson() => {
    'communityId': communityId,
    'content': content,
    'replyToMessageId': replyToMessageId,
    'imageUrls': imageUrls,
    'sharedPlaces': sharedPlaces?.map((p) => p.toJson()).toList(),
    'sharedPosts': sharedPosts?.map((p) => p.toJson()).toList(),
  };
}
