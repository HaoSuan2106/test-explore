/// API DTO models for the "My Recommended Places" module.
///
/// These mirror the ASP.NET Core DTOs in
/// `backend/DTOs/HiddenPlace/HiddenPlaceDtos.cs` (ASP.NET Core default
/// camelCase JSON). Every [fromJson] must tolerate the exact field names
/// returned by the API.
library;

// ============================================================
// Recommended Place
// ============================================================

class RecommendedPlaceSummaryModel {
  const RecommendedPlaceSummaryModel({
    required this.submissionId,
    required this.name,
    required this.locationAddress,
    this.latitude,
    this.longitude,
    required this.category,
    this.description,
    required this.status,
    required this.verificationCount,
    required this.reportCount,
    required this.requiredVerifications,
    required this.createdAt,
    required this.updatedAt,
  });

  final String submissionId;
  final String name;
  final String locationAddress;
  final double? latitude;
  final double? longitude;
  final String category;
  final String? description;
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
      locationAddress: json['locationAddress'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String? ?? '',
      description: json['description'] as String?,
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
    required super.locationAddress,
    super.latitude,
    super.longitude,
    required super.category,
    super.description,
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
    required this.reports,
  });

  final int submitterId;
  final String submitterName;
  final bool isCurrentUserSubmitter;
  final bool isVerifiedByCurrentUser;
  final bool isReportedByCurrentUser;
  final List<RecommendedPlaceReportModel> reports;

  factory RecommendedPlaceDetailsModel.fromJson(Map<String, dynamic> json) {
    return RecommendedPlaceDetailsModel(
      submissionId: json['submissionId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      locationAddress: json['locationAddress'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String? ?? '',
      description: json['description'] as String?,
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
      reports: (json['reports'] as List? ?? const [])
          .map((e) => RecommendedPlaceReportModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ============================================================
// Requests
// ============================================================

class SubmitRecommendedPlaceRequest {
  const SubmitRecommendedPlaceRequest({
    required this.name,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.description,
  });

  final String name;
  final String locationAddress;
  final double latitude;
  final double longitude;
  final String category;
  final String? description;

  Map<String, dynamic> toJson() => {
        'name': name,
        'locationAddress': locationAddress,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        if (description != null && description!.isNotEmpty) 'description': description,
      };
}

class ToggleVerificationRequest {
  const ToggleVerificationRequest({required this.verify});

  final bool verify;

  Map<String, dynamic> toJson() => {'verify': verify};
}

class ReportRecommendedPlaceRequest {
  const ReportRecommendedPlaceRequest({required this.reason});

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

class WithdrawRecommendedPlaceResponse {
  const WithdrawRecommendedPlaceResponse({
    required this.submissionId,
    required this.status,
    required this.message,
  });

  final String submissionId;
  final String status;
  final String message;

  factory WithdrawRecommendedPlaceResponse.fromJson(Map<String, dynamic> json) =>
      WithdrawRecommendedPlaceResponse(
        submissionId: json['submissionId'] as String? ?? '',
        status: json['status'] as String? ?? '',
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

class ReportRecommendedPlaceResponse {
  const ReportRecommendedPlaceResponse({
    required this.reportId,
    required this.submissionId,
    required this.reportCount,
    required this.placeStatus,
    required this.message,
  });

  final String reportId;
  final String submissionId;
  final int reportCount;
  final String placeStatus;
  final String message;

  factory ReportRecommendedPlaceResponse.fromJson(Map<String, dynamic> json) =>
      ReportRecommendedPlaceResponse(
        reportId: json['reportId'] as String? ?? '',
        submissionId: json['submissionId'] as String? ?? '',
        reportCount: _asInt(json['reportCount']),
        placeStatus: json['placeStatus'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

// ============================================================
// Reports
// ============================================================

class RecommendedPlaceReportModel {
  const RecommendedPlaceReportModel({
    required this.reportId,
    required this.submissionId,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String reportId;
  final String submissionId;
  final int reporterId;
  final String reason;
  final String status;
  final DateTime createdAt;

  factory RecommendedPlaceReportModel.fromJson(Map<String, dynamic> json) =>
      RecommendedPlaceReportModel(
        reportId: json['reportId'] as String? ?? '',
        submissionId: json['submissionId'] as String? ?? '',
        reporterId: _asInt(json['reporterId']),
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String? ?? 'ACTIVE',
        createdAt: _asDateTime(json['createdAt']) ?? DateTime.now(),
      );
}

// ============================================================
// UI model — "My Recommended Places" screens
// ============================================================

/// UI model for a recommended place as shown in "My Recommended Places".
class RecommendedPlaceModel {
  final String id;
  final String name;
  final String address;
  final String category;
  final String description;
  String status; // 'UNDER_VOTING', 'VERIFIED', 'REPORTED_CLOSED', 'WITHDRAWN'
  int currentVotes;
  int reportCount;
  final int requiredVotes;
  final DateTime submittedAt;
  bool isVerifiedByCurrentUser;
  bool isReportedByCurrentUser;
  bool isCurrentUserSubmitter;

  RecommendedPlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.description,
    this.status = 'UNDER_VOTING',
    this.currentVotes = 2,
    this.reportCount = 0,
    this.requiredVotes = 5,
    required this.submittedAt,
    this.isVerifiedByCurrentUser = false,
    this.isReportedByCurrentUser = false,
    this.isCurrentUserSubmitter = false,
  });

  bool get isUnderVoting => status == 'UNDER_VOTING';
  bool get isVerified => status == 'VERIFIED';
  bool get isReportedClosed => status == 'REPORTED_CLOSED';
  bool get isWithdrawn => status == 'WITHDRAWN';

  factory RecommendedPlaceModel.fromApi(RecommendedPlaceSummaryModel api) {
    return RecommendedPlaceModel(
      id: api.submissionId,
      name: api.name,
      address: api.locationAddress,
      category: api.category,
      description: api.description ?? '',
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
      address: api.locationAddress,
      category: api.category,
      description: api.description ?? '',
      status: api.status,
      currentVotes: api.verificationCount,
      reportCount: api.reportCount,
      requiredVotes: api.requiredVerifications,
      submittedAt: api.createdAt,
      isVerifiedByCurrentUser: api.isVerifiedByCurrentUser,
      isReportedByCurrentUser: api.isReportedByCurrentUser,
      isCurrentUserSubmitter: api.isCurrentUserSubmitter,
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

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}