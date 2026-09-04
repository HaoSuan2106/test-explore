class VisitLog {
  final String logId;
  final String? placeId;
  final String title;
  final String? primaryType;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String status;
  final String? photoUrl;
  final String? photoAttribution;

  const VisitLog({
    required this.logId,
    this.placeId,
    required this.title,
    this.primaryType,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.startedAt,
    this.endedAt,
    required this.status,
    this.photoUrl,
    this.photoAttribution,
  });

  factory VisitLog.fromJson(Map<String, dynamic> json) {
    return VisitLog(
      logId: json['logId'] as String,
      placeId: json['placeId'] as String?,
      title: json['title'] as String? ?? '',
      primaryType: json['primaryType'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt'] as String) : null,
      status: json['status'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      photoAttribution: json['photoAttribution'] as String?,
    );
  }
}