import 'message_model.dart';

class CommunitySummary {
  const CommunitySummary({
    required this.communityId,
    required this.name,
    this.description,
    this.area,
    this.state,
    this.imageUrl,
    required this.memberCount,
    required this.isJoined,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final int communityId;
  final String name;
  final String? description;
  final String? area;
  final String? state;
  final String? imageUrl;
  final int memberCount;
  final bool isJoined;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  factory CommunitySummary.fromJson(Map<String, dynamic> json) => CommunitySummary(
    communityId: json['communityId'] as int,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    area: json['area'] as String?,
    state: json['state'] as String?,
    imageUrl: json['imageUrl'] as String?,
    memberCount: json['memberCount'] as int? ?? 0,
    isJoined: json['isJoined'] as bool? ?? false,
    lastMessagePreview: json['lastMessagePreview'] as String?,
    lastMessageAt: json['lastMessageAt'] == null ? null : DateTime.parse(json['lastMessageAt'] as String),
  );
}

class CommunityDetail extends CommunitySummary {
  const CommunityDetail({
    required super.communityId,
    required super.name,
    super.description,
    super.area,
    super.state,
    super.imageUrl,
    required super.memberCount,
    required super.isJoined,
    super.lastMessagePreview,
    super.lastMessageAt,
    required this.latestMessages,
  });

  final List<MessageModel> latestMessages;

  factory CommunityDetail.fromJson(Map<String, dynamic> json) => CommunityDetail(
    communityId: json['communityId'] as int,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    area: json['area'] as String?,
    state: json['state'] as String?,
    imageUrl: json['imageUrl'] as String?,
    memberCount: json['memberCount'] as int? ?? 0,
    isJoined: json['isJoined'] as bool? ?? false,
    lastMessagePreview: json['lastMessagePreview'] as String?,
    lastMessageAt: json['lastMessageAt'] == null ? null : DateTime.parse(json['lastMessageAt'] as String),
    latestMessages: (json['latestMessages'] as List<dynamic>? ?? [])
        .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

class ParticipantModel {
  const ParticipantModel({
    required this.userId,
    required this.username,
    this.profilePictureUrl,
    required this.role,
    required this.joinedAt,
    this.isOnline = false,
  });

  final int userId;
  final String username;
  final String? profilePictureUrl;
  final String role; // 'Member' | 'Moderator'
  final DateTime joinedAt;
  final bool isOnline;

  factory ParticipantModel.fromJson(Map<String, dynamic> json) => ParticipantModel(
    userId: json['userId'] as int,
    username: json['username'] as String? ?? 'Unknown User',
    profilePictureUrl: json['profilePictureUrl'] as String?,
    role: json['role'] as String? ?? 'Member',
    joinedAt: DateTime.parse(json['joinedAt'] as String),
  );

  ParticipantModel copyWith({bool? isOnline}) => ParticipantModel(
    userId: userId,
    username: username,
    profilePictureUrl: profilePictureUrl,
    role: role,
    joinedAt: joinedAt,
    isOnline: isOnline ?? this.isOnline,
  );
}
