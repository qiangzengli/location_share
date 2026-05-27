import 'package:flutter/material.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/screens/auth_screen.dart';
import 'package:location_share/screens/map_screen.dart';
import 'package:provider/provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _lastBoundUid;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = auth.user;
    if (user == null) {
      _lastBoundUid = null;
      return const AuthScreen();
    }

    final sharing = context.read<SharingController>();
    if (_lastBoundUid != user.uid ||
        sharing.participantId != user.uid ||
        sharing.displayName != user.displayName) {
      _lastBoundUid = user.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sharing.applyAuthenticatedUser(
          uid: user.uid,
          displayName: user.displayName,
        );
      });
    }

    return const MapScreen();
  }
}
