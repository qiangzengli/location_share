import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:location_share/models/group.dart';

class GroupRepository {
  GroupRepository({
    required this.baseUrl,
    required this.getAccessToken,
  });

  final String baseUrl;
  final Future<String?> Function() getAccessToken;

  Future<Map<String, String>> _headers() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Group>> myGroups() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/groups'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('获取群组列表失败: ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Group> createGroup(String name) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/groups'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 201) {
      throw Exception('创建群组失败: ${resp.statusCode}');
    }
    return Group.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<GroupDetail> groupDetail(String groupId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/groups/$groupId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('获取群组详情失败: ${resp.statusCode}');
    }
    return GroupDetail.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Group> joinGroup(String inviteCode) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/groups/join'),
      headers: await _headers(),
      body: jsonEncode({'inviteCode': inviteCode}),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? '加入群组失败');
    }
    return Group.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> leaveGroup(String groupId) async {
    final resp = await http.delete(
      Uri.parse('$baseUrl/api/groups/$groupId/leave'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 204) {
      throw Exception('退出群组失败: ${resp.statusCode}');
    }
  }

  Future<void> kickMember(String groupId, String userId) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/kick/$userId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 204) {
      throw Exception('踢出成员失败: ${resp.statusCode}');
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final resp = await http.delete(
      Uri.parse('$baseUrl/api/groups/$groupId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 204) {
      throw Exception('解散群组失败: ${resp.statusCode}');
    }
  }

  Future<Group> regenerateCode(String groupId) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/regenerate-code'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('重新生成邀请码失败: ${resp.statusCode}');
    }
    return Group.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Group> updateGroup(String groupId, String name) async {
    final resp = await http.patch(
      Uri.parse('$baseUrl/api/groups/$groupId'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('修改群组失败: ${resp.statusCode}');
    }
    return Group.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}
