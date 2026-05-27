import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:location_share/models/participant_location.dart';
import 'package:location_share/repositories/location_sync_repository.dart';

class HttpLocationSyncRepository implements LocationSyncRepository {
  HttpLocationSyncRepository({
    required this.baseUrl,
    required this.getAccessToken,
  });

  final String baseUrl;
  final Future<String?> Function() getAccessToken;

  static const _pollInterval = Duration(seconds: 3);

  @override
  Future<List<ParticipantLocation>> fetchGroup(String groupId) async {
    final token = await getAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/groups/$groupId/locations'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .map((json) => ParticipantLocation.fromApiJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to fetch locations: ${response.statusCode}');
  }

  @override
  Future<void> upsertMyLocation(ParticipantLocation row) async {
    final token = await getAccessToken();
    final response = await http.put(
      Uri.parse('$baseUrl/api/groups/${row.groupId}/locations/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'participantId': row.participantId,
        'displayName': row.displayName,
        'latitude': row.latitude,
        'longitude': row.longitude,
        'accuracy': row.accuracy,
        'heading': row.heading,
        'speed': row.speed,
        'platform': row.platform,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upsert location: ${response.statusCode}');
    }
  }

  @override
  Stream<List<ParticipantLocation>> watchGroupSnapshots(String groupId) async* {
    while (true) {
      try {
        final locations = await fetchGroup(groupId);
        yield locations;
      } catch (_) {
        // Ignore errors and continue polling
      }
      await Future.delayed(_pollInterval);
    }
  }
}
