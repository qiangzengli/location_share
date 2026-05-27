import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:location_share/models/auth_user.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
  }) : _auth = firebaseAuth;

  final FirebaseAuth? _auth;
  static const _authTimeout = Duration(seconds: 15);

  Stream<AuthUser?> authStateChanges() {
    final auth = _auth;
    if (auth == null) {
      return Stream<AuthUser?>.value(null);
    }
    return auth.authStateChanges().map(_mapUser);
  }

  AuthUser? get currentUser => _mapUser(_auth?.currentUser);

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _requireAuth();
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ).timeout(_authTimeout);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final auth = _requireAuth();
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ).timeout(_authTimeout);

    final user = credential.user;
    if (user == null) return;

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) return;

    // 注册成功后不要让资料更新阻塞登录态进入。
    try {
      await user.updateDisplayName(trimmedName).timeout(_authTimeout);
      await user.reload().timeout(_authTimeout);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('updateDisplayName skipped after register: $error\n$stackTrace');
      }
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _requireAuth().currentUser;
    if (user == null) return;
    await user.updateDisplayName(displayName.trim()).timeout(_authTimeout);
    await user.reload().timeout(_authTimeout);
  }

  Future<void> signOut() {
    return _requireAuth().signOut();
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase Auth 未初始化。');
    }
    return auth;
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    final rawName = user.displayName?.trim();
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: (rawName == null || rawName.isEmpty)
          ? (user.email ?? '未命名用户')
          : rawName,
    );
  }
}
