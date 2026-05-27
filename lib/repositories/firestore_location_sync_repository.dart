import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location_share/models/participant_location.dart';
import 'package:location_share/repositories/location_sync_repository.dart';

class FirestoreLocationSyncRepository implements LocationSyncRepository {
  FirestoreLocationSyncRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _locations =>
      _firestore.collection('participant_locations');

  @override
  Future<List<ParticipantLocation>> fetchGroup(String groupId) async {
    final snapshot =
        await _locations.where('groupId', isEqualTo: groupId).get();
    return _mapDocs(snapshot.docs);
  }

  @override
  Future<void> upsertMyLocation(ParticipantLocation row) async {
    await _locations.doc(_docId(row.groupId, row.participantId)).set(
          row.toFirestoreMap(),
          SetOptions(merge: true),
        );
  }

  @override
  Stream<List<ParticipantLocation>> watchGroupSnapshots(String groupId) {
    return _locations.where('groupId', isEqualTo: groupId).snapshots().map(
          (snapshot) => _mapDocs(snapshot.docs),
        );
  }

  List<ParticipantLocation> _mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = docs
        .map((doc) => ParticipantLocation.fromFirestoreMap(doc.data()))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  String _docId(String groupId, String participantId) {
    final encodedGroup = Uri.encodeComponent(groupId);
    return '${encodedGroup}_$participantId';
  }
}
