/// API DTO models for the Post / PostReview module.
///
/// These mirror the ASP.NET Core DTOs in
/// `backend/DTOs/PostReview/PostDtos.cs` (ASP.NET Core default camelCase
/// JSON). Every [fromJson] must tolerate the exact field names returned by
/// the API; server-side `authorId`/`reporterId` are serialized as strings.
library;

class PostSummaryModel {
  const PostSummaryModel({
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.taggedPlaceId,
    required this.taggedPlaceName,
    required this.taggedPlaceAddress,
    this.title,
    required this.description,
    this.imageUrls = const [],
    this.reactionCount = 0,
    this.commentCount = 0,
    this.reportCount = 0,
    this.isReactedByCurrentUser = false,
    this.isReportedByCurrentUser = false,
    this.isSavedByCurrentUser = false,
    this.viewsCount = 0,
    this.status = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String postId;
  final int authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String taggedPlaceId;
  final String taggedPlaceName;
  final String taggedPlaceAddress;
  final String? title;
  final String description;
  final List<String> imageUrls;
  final int reactionCount;
  final int commentCount;
  final int reportCount;
  final bool isReactedByCurrentUser;
  final bool isReportedByCurrentUser;
  final bool isSavedByCurrentUser;
  final int viewsCount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PostSummaryModel.fromJson(Map<String, dynamic> json) =>
      PostSummaryModel(
        postId: json['postId'] as String? ?? '',
        authorId: _asInt(json['authorId']),
        authorName: json['authorName'] as String? ?? '',
        authorAvatarUrl: json['authorAvatarUrl'] as String?,
        taggedPlaceId: json['taggedPlaceId'] as String? ?? '',
        taggedPlaceName: json['taggedPlaceName'] as String? ?? '',
        taggedPlaceAddress: json['taggedPlaceAddress'] as String? ?? '',
        title: json['title'] as String?,
        description: json['description'] as String? ?? '',
        imageUrls: (json['imageUrls'] as List?)?.cast<String>() ?? const [],
        reactionCount: _asInt(json['reactionCount']),
        commentCount: _asInt(json['commentCount']),
        reportCount: _asInt(json['reportCount']),
        isReactedByCurrentUser: json['isReactedByCurrentUser'] as bool? ?? false,
        isReportedByCurrentUser: json['isReportedByCurrentUser'] as bool? ?? false,
        isSavedByCurrentUser: json['isSavedByCurrentUser'] as bool? ?? false,
        viewsCount: _asInt(json['viewsCount']),
        status: json['status'] as String? ?? '',
        createdAt: _asDateTime(json['createdAt']),
        updatedAt: _asDateTime(json['updatedAt']),
      );
}

class PostDetailsModel extends PostSummaryModel {
  const PostDetailsModel({
    required super.postId,
    required super.authorId,
    required super.authorName,
    super.authorAvatarUrl,
    required super.taggedPlaceId,
    required super.taggedPlaceName,
    required super.taggedPlaceAddress,
    super.title,
    required super.description,
    super.imageUrls,
    super.reactionCount,
    super.commentCount,
    super.reportCount,
    super.isReactedByCurrentUser,
    super.isReportedByCurrentUser,
    super.isSavedByCurrentUser,
    super.viewsCount,
    super.status,
    required super.createdAt,
    required super.updatedAt,
    this.comments = const [],
    this.reports = const [],
  });

  final List<PostCommentModel> comments;
  final List<PostReportModel> reports;

  factory PostDetailsModel.fromJson(Map<String, dynamic> json) =>
      PostDetailsModel(
        postId: json['postId'] as String? ?? '',
        authorId: _asInt(json['authorId']),
        authorName: json['authorName'] as String? ?? '',
        authorAvatarUrl: json['authorAvatarUrl'] as String?,
        taggedPlaceId: json['taggedPlaceId'] as String? ?? '',
        taggedPlaceName: json['taggedPlaceName'] as String? ?? '',
        taggedPlaceAddress: json['taggedPlaceAddress'] as String? ?? '',
        title: json['title'] as String?,
        description: json['description'] as String? ?? '',
        imageUrls: (json['imageUrls'] as List?)?.cast<String>() ?? const [],
        reactionCount: _asInt(json['reactionCount']),
        commentCount: _asInt(json['commentCount']),
        reportCount: _asInt(json['reportCount']),
        isReactedByCurrentUser: json['isReactedByCurrentUser'] as bool? ?? false,
        isReportedByCurrentUser: json['isReportedByCurrentUser'] as bool? ?? false,
        isSavedByCurrentUser: json['isSavedByCurrentUser'] as bool? ?? false,
        viewsCount: _asInt(json['viewsCount']),
        status: json['status'] as String? ?? '',
        createdAt: _asDateTime(json['createdAt']),
        updatedAt: _asDateTime(json['updatedAt']),
        comments: (json['comments'] as List?)
                ?.map((e) => PostCommentModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        reports: (json['reports'] as List?)
                ?.map((e) => PostReportModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class PostCommentModel {
  const PostCommentModel({
    required this.commentId,
    required this.postId,
    this.postTitle = '',
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    this.likesCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String commentId;
  final String postId;
  final String postTitle;
  final int authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final int likesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PostCommentModel.fromJson(Map<String, dynamic> json) =>
      PostCommentModel(
        commentId: json['commentId'] as String? ?? '',
        postId: json['postId'] as String? ?? '',
        postTitle: json['postTitle'] as String? ?? '',
        authorId: _asInt(json['authorId']),
        authorName: json['authorName'] as String? ?? '',
        authorAvatarUrl: json['authorAvatarUrl'] as String?,
        content: json['content'] as String? ?? '',
        likesCount: _asInt(json['likesCount']),
        createdAt: _asDateTime(json['createdAt']),
        updatedAt: _asDateTime(json['updatedAt']),
      );
}

class PostReportModel {
  const PostReportModel({
    required this.reportId,
    required this.postId,
    required this.reporterId,
    required this.reason,
    this.status = '',
    required this.createdAt,
    this.postTitle = '',
    this.postedBy = '',
    this.taggedPlaceName = '',
    this.postDescription = '',
    this.postImageUrl = '',
    this.reactionCount = 0,
    this.commentCount = 0,
  });

  final String reportId;
  final String postId;
  final int reporterId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String postTitle;
  final String postedBy;
  final String taggedPlaceName;
  final String postDescription;
  final String postImageUrl;
  final int reactionCount;
  final int commentCount;

  factory PostReportModel.fromJson(Map<String, dynamic> json) =>
      PostReportModel(
        reportId: json['reportId'] as String? ?? '',
        postId: json['postId'] as String? ?? '',
        reporterId: _asInt(json['reporterId']),
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: _asDateTime(json['createdAt']),
        postTitle: json['postTitle'] as String? ?? '',
        postedBy: json['postedBy'] as String? ?? '',
        taggedPlaceName: json['taggedPlaceName'] as String? ?? '',
        postDescription: json['postDescription'] as String? ?? '',
        postImageUrl: json['postImageUrl'] as String? ?? '',
        reactionCount: _asInt(json['reactionCount']),
        commentCount: _asInt(json['commentCount']),
      );
}

class EligibleAttractionModel {
  const EligibleAttractionModel({
    required this.placeId,
    required this.name,
    required this.address,
    required this.category,
    this.description,
  });

  final String placeId;
  final String name;
  final String address;
  final String category;
  final String? description;

  factory EligibleAttractionModel.fromJson(Map<String, dynamic> json) =>
      EligibleAttractionModel(
        placeId: json['placeId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String?,
      );
}

// ============================================================
// Request bodies
// ============================================================

class PostImageRequest {
  const PostImageRequest({required this.imageUrl, required this.displayOrder});

  final String imageUrl;
  final int displayOrder;

  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl,
        'displayOrder': displayOrder,
      };
}

class CreatePostRequest {
  const CreatePostRequest({
    required this.taggedPlaceId,
    this.title,
    required this.description,
    this.images = const [],
  });

  final String taggedPlaceId;
  final String? title;
  final String description;
  final List<PostImageRequest> images;

  Map<String, dynamic> toJson() => {
        'taggedPlaceId': taggedPlaceId,
        if (title != null) 'title': title,
        'description': description,
        'images': images.map((i) => i.toJson()).toList(),
      };
}

class UpdatePostRequest {
  const UpdatePostRequest({
    this.title,
    required this.description,
    this.images = const [],
  });

  final String? title;
  final String description;
  final List<PostImageRequest> images;

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        'description': description,
        'images': images.map((i) => i.toJson()).toList(),
      };
}

class CreateCommentRequest {
  const CreateCommentRequest({required this.content});

  final String content;

  Map<String, dynamic> toJson() => {'content': content};
}

class UpdateCommentRequest {
  const UpdateCommentRequest({required this.content});

  final String content;

  Map<String, dynamic> toJson() => {'content': content};
}

class ToggleReactionRequest {
  const ToggleReactionRequest({this.reactionType = 'LIKE'});

  final String reactionType;

  Map<String, dynamic> toJson() => {'reactionType': reactionType};
}

class CreateReportRequest {
  const CreateReportRequest({required this.reason});

  final String reason;

  Map<String, dynamic> toJson() => {'reason': reason};
}

// ============================================================
// Response envelopes
// ============================================================

class CreatePostResponse {
  const CreatePostResponse({required this.postId, required this.message});

  final String postId;
  final String message;

  factory CreatePostResponse.fromJson(Map<String, dynamic> json) =>
      CreatePostResponse(
        postId: json['postId'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

class UpdatePostResponse {
  const UpdatePostResponse({this.post, required this.message});

  final PostSummaryModel? post;
  final String message;

  factory UpdatePostResponse.fromJson(Map<String, dynamic> json) =>
      UpdatePostResponse(
        post: json['post'] is Map<String, dynamic>
            ? PostSummaryModel.fromJson(json['post'] as Map<String, dynamic>)
            : null,
        message: json['message'] as String? ?? '',
      );
}

class DeletePostResponse {
  const DeletePostResponse({required this.postId, required this.message});

  final String postId;
  final String message;

  factory DeletePostResponse.fromJson(Map<String, dynamic> json) =>
      DeletePostResponse(
        postId: json['postId'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

class CreateCommentResponse {
  const CreateCommentResponse({this.comment, required this.message});

  final PostCommentModel? comment;
  final String message;

  factory CreateCommentResponse.fromJson(Map<String, dynamic> json) =>
      CreateCommentResponse(
        comment: json['comment'] is Map<String, dynamic>
            ? PostCommentModel.fromJson(json['comment'] as Map<String, dynamic>)
            : null,
        message: json['message'] as String? ?? '',
      );
}

class UpdateCommentResponse {
  const UpdateCommentResponse({this.comment, required this.message});

  final PostCommentModel? comment;
  final String message;

  factory UpdateCommentResponse.fromJson(Map<String, dynamic> json) =>
      UpdateCommentResponse(
        comment: json['comment'] is Map<String, dynamic>
            ? PostCommentModel.fromJson(json['comment'] as Map<String, dynamic>)
            : null,
        message: json['message'] as String? ?? '',
      );
}

class DeleteCommentResponse {
  const DeleteCommentResponse({required this.commentId, required this.message});

  final String commentId;
  final String message;

  factory DeleteCommentResponse.fromJson(Map<String, dynamic> json) =>
      DeleteCommentResponse(
        commentId: json['commentId'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

class ToggleReactionResponse {
  const ToggleReactionResponse({
    required this.postId,
    required this.reactionType,
    required this.isReacted,
    required this.reactionCount,
  });

  final String postId;
  final String reactionType;
  final bool isReacted;
  final int reactionCount;

  factory ToggleReactionResponse.fromJson(Map<String, dynamic> json) =>
      ToggleReactionResponse(
        postId: json['postId'] as String? ?? '',
        reactionType: json['reactionType'] as String? ?? '',
        isReacted: json['isReacted'] as bool? ?? false,
        reactionCount: _asInt(json['reactionCount']),
      );
}

class CreateReportResponse {
  const CreateReportResponse({
    required this.reportId,
    required this.postId,
    required this.reportCount,
    required this.message,
  });

  final String reportId;
  final String postId;
  final int reportCount;
  final String message;

  factory CreateReportResponse.fromJson(Map<String, dynamic> json) =>
      CreateReportResponse(
        reportId: json['reportId'] as String? ?? '',
        postId: json['postId'] as String? ?? '',
        reportCount: _asInt(json['reportCount']),
        message: json['message'] as String? ?? '',
      );
}

class SavePostResponse {
  const SavePostResponse({
    required this.postId,
    required this.isSaved,
    required this.message,
  });

  final String postId;
  final bool isSaved;
  final String message;

  factory SavePostResponse.fromJson(Map<String, dynamic> json) =>
      SavePostResponse(
        postId: json['postId'] as String? ?? '',
        isSaved: json['isSaved'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );
}

// ============================================================
// Helpers
// ============================================================

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

DateTime _asDateTime(dynamic value) {
  if (value is DateTime) return value;
  final parsed = DateTime.tryParse('$value');
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
}
