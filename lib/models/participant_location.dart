import 'package:x_amap_flutter_base/amap_flutter_base.dart';

/// One row in `participant_locations` (and local "me" snapshot).
class ParticipantLocation {
  const ParticipantLocation({
    required this.groupId,
    required this.participantId,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.heading,
    this.speed,
    required this.updatedAt,
    this.platform = '',
  });

  final String groupId;
  final String participantId;
  final String displayName;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final DateTime updatedAt;
  final String platform;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toUpsertMap() {
    return {
      'group_id': groupId,
      'participant_id': participantId,
      'display_name': displayName,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'heading': heading,
      'speed': speed,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'platform': platform,
    };
  }

  factory ParticipantLocation.fromMap(Map<String, dynamic> m) {
    return ParticipantLocation(
      groupId: m['group_id'] as String? ?? '',
      participantId: m['participant_id'] as String? ?? '',
      displayName: m['display_name'] as String? ?? '',
      latitude: _asDouble(m['latitude']) ?? 0,
      longitude: _asDouble(m['longitude']) ?? 0,
      accuracy: _asDouble(m['accuracy']),
      heading: _asDouble(m['heading']),
      speed: _asDouble(m['speed']),
      updatedAt: _parseTime(m['updated_at']),
      platform: m['platform'] as String? ?? '',
    );
  }

  /// Spring Boot JSON（camelCase），与 [fromMap] 的 snake_case 二选一。
  factory ParticipantLocation.fromApiJson(Map<String, dynamic> m) {
    return ParticipantLocation(
      groupId: m['groupId'] as String? ?? '',
      participantId: m['participantId'] as String? ?? '',
      displayName: m['displayName'] as String? ?? '',
      latitude: _asDouble(m['latitude']) ?? 0,
      longitude: _asDouble(m['longitude']) ?? 0,
      accuracy: _asDouble(m['accuracy']),
      heading: _asDouble(m['heading']),
      speed: _asDouble(m['speed']),
      updatedAt: _parseTime(m['updatedAt']),
      platform: m['platform'] as String? ?? '',
    );
  }

  static double? _asDouble(Object? v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime _parseTime(Object? v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is DateTime) return v;
    if (v is String) {
      return DateTime.tryParse(v)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
