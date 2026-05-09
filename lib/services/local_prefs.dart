import 'package:shared_preferences/shared_preferences.dart';

class LocalPrefs {
  static const _kParticipantId = 'participant_id';
  static const _kDisplayName = 'display_name';
  static const _kGroupId = 'group_id';
  static const _kAmapPrivacyOk = 'amap_privacy_ok';
  static const _kSharingEnabled = 'sharing_enabled';
  static const _kBackendAccessToken = 'backend_access_token';

  static const defaultGroupId = 'groups/dev_family';

  Future<String?> getParticipantId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kParticipantId);
  }

  Future<void> setParticipantId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kParticipantId, id);
  }

  Future<String> getDisplayName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kDisplayName) ?? '我';
  }

  Future<void> setDisplayName(String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDisplayName, name);
  }

  Future<String> getGroupId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kGroupId) ?? defaultGroupId;
  }

  Future<void> setGroupId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGroupId, id);
  }

  Future<bool> getAmapPrivacyAccepted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAmapPrivacyOk) ?? false;
  }

  Future<void> setAmapPrivacyAccepted(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAmapPrivacyOk, v);
  }

  Future<bool> getSharingEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kSharingEnabled) ?? false;
  }

  Future<void> setSharingEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSharingEnabled, v);
  }

  /// Spring Boot JWT access token（登录后写入，供 HTTP 位置同步使用）。
  Future<String?> getBackendAccessToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kBackendAccessToken);
  }

  Future<void> setBackendAccessToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await p.remove(_kBackendAccessToken);
    } else {
      await p.setString(_kBackendAccessToken, token);
    }
  }
}
