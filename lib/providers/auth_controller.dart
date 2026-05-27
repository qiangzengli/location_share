import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:location_share/models/auth_user.dart';
import 'package:location_share/services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    AuthService? authService,
  }) : _authService = authService;

  final AuthService? _authService;

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

    user = authService.currentUser;
    _authSub = authService.authStateChanges().listen((nextUser) {
      user = nextUser;
      initialized = true;
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

  Future<bool> updateDisplayName(String displayName) async {
    return _runAuthAction(() {
      return _authService!.updateDisplayName(displayName);
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
      errorMessage = '请求超时，请检查网络或稍后重试。';
      return false;
    } on FirebaseAuthException catch (error) {
      errorMessage = _mapFirebaseError(error);
      return false;
    } catch (error) {
      errorMessage = '操作失败，请稍后重试。';
      if (kDebugMode) {
        debugPrint('auth action failed: $error');
      }
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String _mapFirebaseError(FirebaseAuthException error) {
    final message = error.message ?? '';
    if (error.code == 'internal-error' &&
        message.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Auth 配置不完整：请在 Firebase Android 应用里补充 SHA-1/SHA-256 指纹，并确认已启用邮箱密码登录。';
    }
    return switch (error.code) {
      'invalid-email' => '邮箱格式不正确。',
      'user-disabled' => '该账号已被禁用。',
      'user-not-found' => '账号不存在。',
      'wrong-password' => '密码错误。',
      'email-already-in-use' => '该邮箱已被注册。',
      'weak-password' => '密码强度太弱，请至少使用 6 位字符。',
      'invalid-credential' => '邮箱或密码不正确。',
      'too-many-requests' => '尝试次数过多，请稍后再试。',
      'network-request-failed' => '网络请求失败，请检查网络连接。',
      'internal-error' => 'Firebase 内部配置异常，请检查项目配置后重试。',
      _ => error.message ?? '认证失败，请稍后重试。',
    };
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }
}
