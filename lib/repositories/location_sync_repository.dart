import 'package:location_share/models/participant_location.dart';

/// 位置同步抽象（当前实现为 Firebase Firestore 实时同步）。
abstract class LocationSyncRepository {
  Future<List<ParticipantLocation>> fetchGroup(String groupId);

  Future<void> upsertMyLocation(ParticipantLocation row);

  /// Full snapshot list after initial load and after each realtime change.
  Stream<List<ParticipantLocation>> watchGroupSnapshots(String groupId);
}
