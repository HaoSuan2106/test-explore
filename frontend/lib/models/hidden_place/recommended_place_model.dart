/// API DTO models for the "My Recommended Places" module.
///
/// These mirror the ASP.NET Core DTOs in
/// `backend/DTOs/HiddenPlace/HiddenPlaceDtos.cs` (ASP.NET Core default
/// camelCase JSON). Every [fromJson] must tolerate the exact field names
/// returned by the API.
library;

import 'dart:convert';

// ============================================================
// Recommended Place
// ============================================================

class RecommendedPlaceSummaryModel {
  const RecommendedPlaceSummaryModel({
    required this.submissionId,
    required this.name,
    this.latitude,
    this.longitude,
    required this.primaryType,
    this.description,
    this.priceLevel,
    this.businessStatus,
    this.photosJson,
    required this.status,
    required this.verificationCount,
    required this.reportCount,
    required this.requiredVerifications,
    required this.createdAt,
    required this.updatedAt,
  });

  final String submissionId;
  final String name;
  final double? latitude;
  final double? longitude;
  final String primaryType;
  final String? description;
  final int? priceLevel;
  final String? businessStatus;
  final List<String>? photosJson;
  final String status; // UNDER_VOTING | VERIFIED | REPORTED_CLOSED | WITHDRAWN
  final int verificationCount;
  final int reportCount;
  final int requiredVerifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RecommendedPlaceSummaryModel.fromJson(Map<String, dynamic> json) {
    return RecommendedPlaceSummaryModel(
      submissionId: json['submissionId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      primaryType: json['primaryType'] as String? ?? '',
      description: json['description'] as String?,
      priceLevel: (json['priceLevel'] as num?)?.toInt(),
      businessStatus: json['businessStatus'] as String?,
      photosJson: _asStringList(json['photosJson']),
      status: json['status'] as String? ?? 'UNDER_VOTING',
      verificationCount: _asInt(json['verificationCount']),
      reportCount: _asInt(json['reportCount']),
      requiredVerifications: _asInt(json['requiredVerifications']),
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class RecommendedPlaceDetailsModel extends RecommendedPlaceSummaryModel {
  const RecommendedPlaceDetailsModel({
    required super.submissionId,
    required super.name,
    super.latitude,
    super.longitude,
    required super.primaryType,
    super.description,
    super.priceLevel,
    super.businessStatus,
    super.photosJson,
    required super.status,
    required super.verificationCount,
    required super.reportCount,
    required super.requiredVerifications,
    required super.createdAt,
    required super.updatedAt,
    required this.submitterId,
    required this.submitterName,
    required this.isCurrentUserSubmitter,
    required this.isVerifiedByCurrentUser,
    required this.isReportedByCurrentUser,
  });

  final int submitterId;
  final String submitterName;
  final bool isCurrentUserSubmitter;
  final bool isVerifiedByCurrentUser;
  final bool isReportedByCurrentUser;

  factory RecommendedPlaceDetailsModel.fromJson(Map<String, dynamic> json) {
    return RecommendedPlaceDetailsModel(
      submissionId: json['submissionId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      primaryType: json['primaryType'] as String? ?? '',
      description: json['description'] as String?,
      priceLevel: (json['priceLevel'] as num?)?.toInt(),
      businessStatus: json['businessStatus'] as String?,
      photosJson: _asStringList(json['photosJson']),
      status: json['status'] as String? ?? 'UNDER_VOTING',
      verificationCount: _asInt(json['verificationCount']),
      reportCount: _asInt(json['reportCount']),
      requiredVerifications: _asInt(json['requiredVerifications']),
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(json['updatedAt']) ?? DateTime.now(),
      submitterId: _asInt(json['submitterId']),
      submitterName: json['submitterName'] as String? ?? 'Unknown',
      isCurrentUserSubmitter: json['isCurrentUserSubmitter'] as bool? ?? false,
      isVerifiedByCurrentUser: json['isVerifiedByCurrentUser'] as bool? ?? false,
      isReportedByCurrentUser: json['isReportedByCurrentUser'] as bool? ?? false,
    );
  }
}

// ============================================================
// Requests
// ============================================================

class SubmitRecommendedPlaceRequest {
  const SubmitRecommendedPlaceRequest({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.primaryType,
    this.description,
    this.priceLevel,
    this.businessStatus,
    this.photosJson,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String primaryType;
  final String? description;
  final int? priceLevel;
  final String? businessStatus;
  final List<String>? photosJson;

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'primaryType': primaryType,
    if (description != null && description!.isNotEmpty) 'description': description,
    if (priceLevel != null) 'priceLevel': priceLevel,
    if (businessStatus != null && businessStatus!.isNotEmpty) 'businessStatus': businessStatus,
    if (photosJson != null && photosJson!.isNotEmpty) 'photosJson': photosJson,
  };
}

class ToggleVerificationRequest {
  const ToggleVerificationRequest({required this.verify});

  final bool verify;

  Map<String, dynamic> toJson() => {'verify': verify};
}

class ReportPlaceRequest {
  const ReportPlaceRequest({required this.reason});

  final String reason;

  Map<String, dynamic> toJson() => {'reason': reason};
}

// ============================================================
// Responses
// ============================================================

class SubmitRecommendedPlaceResponse {
  const SubmitRecommendedPlaceResponse({required this.submissionId, required this.message});

  final String submissionId;
  final String message;

  factory SubmitRecommendedPlaceResponse.fromJson(Map<String, dynamic> json) =>
      SubmitRecommendedPlaceResponse(
        submissionId: json['submissionId'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

class ToggleVerificationResponse {
  const ToggleVerificationResponse({
    required this.submissionId,
    required this.isVerified,
    required this.verificationCount,
    required this.placeStatus,
    required this.message,
  });

  final String submissionId;
  final bool isVerified;
  final int verificationCount;
  final String placeStatus;
  final String message;

  factory ToggleVerificationResponse.fromJson(Map<String, dynamic> json) =>
      ToggleVerificationResponse(
        submissionId: json['submissionId'] as String? ?? '',
        isVerified: json['isVerified'] as bool? ?? false,
        verificationCount: _asInt(json['verificationCount']),
        placeStatus: json['placeStatus'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

class ReportPlaceResponse {
  const ReportPlaceResponse({
    required this.submissionId,
    required this.reportCount,
    required this.placeStatus,
    required this.message,
  });

  final String submissionId;
  final int reportCount;
  final String placeStatus;
  final String message;

  factory ReportPlaceResponse.fromJson(Map<String, dynamic> json) =>
      ReportPlaceResponse(
        submissionId: json['submissionId'] as String? ?? '',
        reportCount: _asInt(json['reportCount']),
        placeStatus: json['placeStatus'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

// ============================================================
// UI model — "My Recommended Places" screens
// ============================================================

/// UI model for a recommended place as shown in "My Recommended Places".
class RecommendedPlaceModel {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final String primaryType;
  final String description;
  final int? priceLevel;
  final String? businessStatus;
  final List<String>? photosJson;
  String status; // 'UNDER_VOTING', 'VERIFIED', 'REPORTED_CLOSED', 'WITHDRAWN'
  int currentVotes;
  int reportCount;
  final int requiredVotes;
  final DateTime submittedAt;
  bool isVerifiedByCurrentUser;
  bool isCurrentUserSubmitter;
  bool isReportedByCurrentUser;
  final String submitterName;

  RecommendedPlaceModel({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    required this.primaryType,
    required this.description,
    this.priceLevel,
    this.businessStatus,
    this.photosJson,
    this.status = 'UNDER_VOTING',
    this.currentVotes = 2,
    this.reportCount = 0,
    this.requiredVotes = 5,
    required this.submittedAt,
    this.isVerifiedByCurrentUser = false,
    this.isCurrentUserSubmitter = false,
    this.isReportedByCurrentUser = false,
    this.submitterName = '',
  });

  bool get isUnderVoting => status == 'UNDER_VOTING';
  bool get isVerified => status == 'VERIFIED';
  bool get isReportedClosed => status == 'REPORTED_CLOSED';
  bool get isWithdrawn => status == 'WITHDRAWN';

  factory RecommendedPlaceModel.fromApi(RecommendedPlaceSummaryModel api) {
    return RecommendedPlaceModel(
      id: api.submissionId,
      name: api.name,
      latitude: api.latitude,
      longitude: api.longitude,
      primaryType: api.primaryType,
      description: api.description ?? '',
      priceLevel: api.priceLevel,
      businessStatus: api.businessStatus,
      photosJson: api.photosJson,
      status: api.status,
      currentVotes: api.verificationCount,
      reportCount: api.reportCount,
      requiredVotes: api.requiredVerifications,
      submittedAt: api.createdAt,
    );
  }

  factory RecommendedPlaceModel.fromDetails(RecommendedPlaceDetailsModel api) {
    return RecommendedPlaceModel(
      id: api.submissionId,
      name: api.name,
      latitude: api.latitude,
      longitude: api.longitude,
      primaryType: api.primaryType,
      description: api.description ?? '',
      priceLevel: api.priceLevel,
      businessStatus: api.businessStatus,
      photosJson: api.photosJson,
      status: api.status,
      currentVotes: api.verificationCount,
      reportCount: api.reportCount,
      requiredVotes: api.requiredVerifications,
      submittedAt: api.createdAt,
      isVerifiedByCurrentUser: api.isVerifiedByCurrentUser,
      isCurrentUserSubmitter: api.isCurrentUserSubmitter,
      isReportedByCurrentUser: api.isReportedByCurrentUser,
      submitterName: api.submitterName,
    );
  }
}

// ============================================================
// Helpers
// ============================================================

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

List<String>? _asStringList(dynamic value) {
  print('[PhotosJson] _asStringList(input type: ${value.runtimeType}, value: $value)');
  if (value == null) {
    print('[PhotosJson] _asStringList -> null (input was null, no photos)');
    return null;
  }
  if (value is List) {
    final result = value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    print('[PhotosJson] _asStringList -> List (${result.length} urls): $result');
    return result;
  }
  if (value is String && value.trim().isNotEmpty) {
    print('[PhotosJson] _asStringList: input is String, trying jsonDecode...');
    final decoded = _tryDecodeJsonArray(value);
    print('[PhotosJson] _asStringList -> decoded result: $decoded');
    if (decoded != null) return decoded;
  }
  print('[PhotosJson] _asStringList -> null (unrecognized format)');
  return null;
}

List<String>? _tryDecodeJsonArray(String raw) {
  print('[PhotosJson] _tryDecodeJsonArray(raw: $raw)');
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      final result = decoded
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      print('[PhotosJson] _tryDecodeJsonArray -> jsonDecode OK, ${result.length} urls: $result');
      return result;
    }
    print('[PhotosJson] _tryDecodeJsonArray -> decoded is ${decoded.runtimeType} (not a List), returning null');
  } catch (_) {
    // Not valid JSON — treat as absent.
    print('[PhotosJson] _tryDecodeJsonArray -> jsonDecode FAILED (invalid JSON), returning null');
  }
  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}