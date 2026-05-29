import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:location_share/models/auth_user.dart';
import 'package:location_share/services/local_prefs.dart';

class HttpAuthService {
  HttpAuthService({
    required this.baseUrl,
    required this.prefs,
  });

  final String baseUrl;
  final LocalPrefs prefs;

  static const _timeout = Duration(seconds: 15);
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'auth_user_json';

  final _authStateController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  Stream<AuthUser?> authStateChanges() => _authStateController.stream;
  AuthUser? get currentUser => _currentUser;

  Future<void> initialize() async {
    final token = await prefs.getString(_accessTokenKey);
    final userJson = await prefs.getString(_userKey);
    if (token != null && userJson != null) {
      try {
        _currentUser = AuthUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        _authStateController.add(_currentUser);
      } catch (_) {
        await prefs.remove(_accessTokenKey);
        await prefs.remove(_refreshTokenKey);
        await prefs.remove(_userKey);
      }
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': email.trim(),
        'password': password,
      }),
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      await _handleAuthResponse(response.body);
    } else {
      throw HttpAuthException.fromResponse(response);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': email.trim(),
        'password': password,
        'email': email.trim(),
        'displayName': displayName.trim(),
      }),
    ).timeout(_timeout);

    if (response.statusCode == 201) {
      await _handleAuthResponse(response.body);
    } else {
      throw HttpAuthException.fromResponse(response);
    }
  }

  Future<void> signOut() async {
    final refreshToken = await prefs.getString(_refreshTokenKey);
    if (refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        ).timeout(_timeout);
      } catch (_) {
        // Ignore logout errors
      }
    }

    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
    _currentUser = null;
    _authStateController.add(null);
  }

  Future<String?> getAccessToken() async {
    final token = await prefs.getString(_accessTokenKey);
    if (token == null) return null;

    // Check if token is expired by decoding JWT payload
    if (_isTokenExpired(token)) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return prefs.getString(_accessTokenKey);
      }
      return null;
    }
    return token;
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = parts[1];
      // Add padding for base64
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'] as int;
      // Consider expired if less than 60s remaining
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 60;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await prefs.getString(_refreshTokenKey);
    if (refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        await _handleAuthResponse(response.body);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _handleAuthResponse(String body) async {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final accessToken = json['accessToken'] as String;
    final refreshToken = json['refreshToken'] as String;
    final userJson = json['user'] as Map<String, dynamic>;

    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_userKey, jsonEncode(userJson));

    _currentUser = AuthUser.fromJson(userJson);
    _authStateController.add(_currentUser);
  }

  void dispose() {
    _authStateController.close();
  }
}

class HttpAuthException implements Exception {
  HttpAuthException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  factory HttpAuthException.fromResponse(http.Response response) {
    final statusCode = response.statusCode;
    String message;

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      message = json['message'] as String? ?? '操作失败';
    } catch (_) {
      message = _defaultMessage(statusCode);
    }

    return HttpAuthException(message, statusCode);
  }

  static String _defaultMessage(int statusCode) {
    return switch (statusCode) {
      400 => '请求参数错误',
      401 => '邮箱或密码不正确',
      403 => '账号已被禁用',
      409 => '该邮箱已被注册',
      _ => '操作失败，请稍后重试',
    };
  }

  @override
  String toString() => message;
}
