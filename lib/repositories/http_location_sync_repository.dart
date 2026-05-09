import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:location_share/config/env.dart';
import 'package:location_share/models/participant_location.dart';
import 'package:location_share/repositories/location_sync_repository.dart';
import 'package:location_share/services/local_prefs.dart';

/// 通过 Spring Boot 上传 / 轮询拉取分组位置（需登录后的 access token）。
class HttpLocationSyncRepository implements LocationSyncRepository {
  HttpLocationSyncRepository({
    required this.prefs,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final LocalPrefs prefs;
  final http.Client _http;

  static const _pollInterval = Duration(seconds: 2);

  String get _root => Env.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<String?> _resolveToken() async {
    final stored = await prefs.getBackendAccessToken();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    if (Env.apiAccessToken.isNotEmpty) {
      return Env.apiAccessToken;
    }
    return null;
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Uri _listUri(String groupId) => Uri.parse(
        '$_root/api/groups/${Uri.encodeComponent(groupId)}/locations',
      );

  Uri _upsertUri(String groupId) => Uri.parse(
        '$_root/api/groups/${Uri.encodeComponent(groupId)}/locations/me',
      );

  @override
  Future<List<ParticipantLocation>> fetchGroup(String groupId) async {
    final token = await _resolveToken();
    if (token == null) {
      throw StateError('未配置后端访问令牌：请先登录并保存 token，或使用 --dart-define=API_ACCESS_TOKEN');
    }
    final res = await _http.get(_listUri(groupId), headers: _headers(token));
    if (res.statusCode != 200) {
      throw Exception('拉取位置失败 HTTP ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final list = List<dynamic>.from(decoded as List<dynamic>);
    return list
        .map(
          (e) => ParticipantLocation.fromApiJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertMyLocation(ParticipantLocation row) async {
    final token = await _resolveToken();
    if (token == null) {
      return;
    }
    final payload = <String, dynamic>{
      'participantId': row.participantId,
      'latitude': row.latitude,
      'longitude': row.longitude,
      'displayName': row.displayName,
      'platform': row.platform,
    };
    if (row.accuracy != null) payload['accuracy'] = row.accuracy;
    if (row.heading != null) payload['heading'] = row.heading;
    if (row.speed != null) payload['speed'] = row.speed;

    final res = await _http.put(
      _upsertUri(row.groupId),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) {
      throw Exception('上传位置失败 HTTP ${res.statusCode}: ${res.body}');
    }
  }

  @override
  Stream<List<ParticipantLocation>> watchGroupSnapshots(String groupId) async* {
    try {
      yield await fetchGroup(groupId);
    } catch (_) {
      yield <ParticipantLocation>[];
    }
    yield* Stream.periodic(_pollInterval, (_) => groupId).asyncMap((gid) async {
      try {
        return await fetchGroup(gid);
      } catch (_) {
        return <ParticipantLocation>[];
      }
    });
  }
}
