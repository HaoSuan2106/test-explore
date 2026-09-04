class MessageAttachmentModel {
  const MessageAttachmentModel({
    required this.attachmentId,
    required this.type,
    this.mediaUrl,
    this.placeId,
    this.placeName,
    this.placeAddress,
    this.placeImageUrl,
    this.placeStatus,
    this.placeLatitude,
    this.placeLongitude,
    this.placePrimaryType,
    this.isCommunityPlace = false,
  });

  final int attachmentId;
  final String type; // 'Image' | 'PlaceShare'
  final String? mediaUrl;

  // Real place identifiers (a Google Place ID, or a recommended place's
  // submission UUID) are strings, never an int.
  final String? placeId;
  final String? placeName;
  final String? placeAddress;
  final String? placeImageUrl;
  final String? placeStatus;

  /// Coordinates + category captured at share time — see Share Location.
  /// Enough to reconstruct a lightweight PlaceData and reopen PlaceDetailUI
  /// without a live re-fetch, the same way the Favourites/Exploration
  /// History screens already build PlaceData from their own lighter models.
  final double? placeLatitude;
  final double? placeLongitude;
  final String? placePrimaryType;

  /// True when [placeId] is a recommend_place_id (community submission)
  /// rather than a Google Place ID — drives PlaceDetailUI's Community button.
  final bool isCommunityPlace;

  factory MessageAttachmentModel.fromJson(Map<String, dynamic> json) => MessageAttachmentModel(
    attachmentId: json['attachmentId'] as int,
    type: json['type'] as String,
    mediaUrl: json['mediaUrl'] as String?,
    placeId: json['placeId'] as String?,
    placeName: json['placeName'] as String?,
    placeAddress: json['placeAddress'] as String?,
    placeImageUrl: json['placeImageUrl'] as String?,
    placeStatus: json['placeStatus'] as String?,
    placeLatitude: (json['placeLatitude'] as num?)?.toDouble(),
    placeLongitude: (json['placeLongitude'] as num?)?.toDouble(),
    placePrimaryType: json['placePrimaryType'] as String?,
    isCommunityPlace: json['isCommunityPlace'] as bool? ?? false,
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
    required this.placeName,
    required this.placeLatitude,
    required this.placeLongitude,
    this.placeAddress,
    this.placeImageUrl,
    this.placeStatus,
    this.placePrimaryType,
    this.isCommunityPlace = false,
  });

  final String placeId;
  final String placeName;
  final String? placeAddress;
  final String? placeImageUrl;
  final String? placeStatus;
  final double placeLatitude;
  final double placeLongitude;
  final String? placePrimaryType;
  final bool isCommunityPlace;

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'placeName': placeName,
    'placeAddress': placeAddress,
    'placeImageUrl': placeImageUrl,
    'placeStatus': placeStatus,
    'placeLatitude': placeLatitude,
    'placeLongitude': placeLongitude,
    'placePrimaryType': placePrimaryType,
    'isCommunityPlace': isCommunityPlace,
  };
}

class SendMessageRequest {
  const SendMessageRequest({
    required this.communityId,
    this.content,
    this.replyToMessageId,
    this.imageUrls,
    this.sharedPlaces,
  });

  final int communityId;
  final String? content;
  final int? replyToMessageId;
  final List<String>? imageUrls;
  final List<SharedPlaceRequest>? sharedPlaces;

  Map<String, dynamic> toJson() => {
    'communityId': communityId,
    'content': content,
    'replyToMessageId': replyToMessageId,
    'imageUrls': imageUrls,
    'sharedPlaces': sharedPlaces?.map((p) => p.toJson()).toList(),
  };
}
