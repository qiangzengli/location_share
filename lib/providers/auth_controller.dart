import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:location_share/models/auth_user.dart';
import 'package:location_share/services/http_auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    HttpAuthService? authService,
  }) : _authService = authService;

  final HttpAuthService? _authService;

  StreamSubscription<AuthUser?>? _authSub;

  AuthUser? user;
  bool initialized = false;
  bool isBusy = false;
  String? errorMessage;

  bool get isLoggedIn => user != null;
  bool get isEnabled => _authService != null;

  Future<void> initialize() async {
    final authService = _authService;
    if (authService == null) {
      initialized = true;
      notifyListeners();
      return;
    }

    await authService.initialize();
    user = authService.currentUser;
    _authSub = authService.authStateChanges().listen((nextUser) {
      user = nextUser;
      notifyListeners();
    });
    initialized = true;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    return _runAuthAction(() {
      return _authService!.signIn(email: email, password: password);
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _runAuthAction(() {
      return _authService!.register(
        email: email,
        password: password,
        displayName: displayName,
      );
    });
  }

  Future<void> signOut() async {
    errorMessage = null;
    notifyListeners();
    final authService = _authService;
    if (authService != null) {
      await authService.signOut();
    }
  }

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on TimeoutException {
      errorMessage = '请求超时（超过15秒），请检查网络后重试。';
      return false;
    } on HttpAuthException catch (error) {
      errorMessage = error.message;
      return false;
    } on SocketException catch (error) {
      errorMessage = '网络连接失败：${error.message}';
      return false;
    } on HandshakeException catch (error) {
      errorMessage = 'SSL握手失败：${error.message}';
      return false;
    } on http.ClientException catch (error) {
      errorMessage = '网络请求失败：${error.message}';
      return false;
    } catch (error) {
      errorMessage = '操作失败：$error';
      if (kDebugMode) {
        debugPrint('auth action failed: $error');
      }
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }
}
