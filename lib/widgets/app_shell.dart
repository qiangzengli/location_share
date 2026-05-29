import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/screens/auth_screen.dart';
import 'package:location_share/screens/groups_screen.dart';
import 'package:location_share/screens/map_screen.dart';
import 'package:location_share/screens/settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _lastBoundUid;
  int _currentIndex = 0;

  Future<void> _requestAndroidPermissions() async {
    if (!Platform.isAndroid) return;
    await [
      Permission.notification,
      Permission.locationWhenInUse,
      Permission.camera,
    ].request();
  }

  static const _screens = <Widget>[
    MapScreen(),
    GroupsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.initialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('初始化中…'),
            ],
          ),
        ),
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
        context.read<GroupController>().initialize();
        _requestAndroidPermissions();
      });
    }

    final groupController = context.watch<GroupController>();
    final activeId = groupController.activeGroupId;
    if (activeId != null && activeId != sharing.groupId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sharing.setGroupId(activeId);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: '地图'),
          NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: '群组'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置'),
        ],
      ),
    );
  }
}
