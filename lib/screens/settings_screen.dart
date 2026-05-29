import 'package:flutter/material.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late TextEditingController _nameCtrl;
  PermissionStatus _locationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final c = context.read<SharingController>();
    _nameCtrl = TextEditingController(text: c.displayName);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermission();
    }
  }

  Future<void> _refreshPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (mounted) setState(() => _locationStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SharingController>();
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(auth.user?.displayName ?? c.displayName),
            subtitle: Text(auth.isLoggedIn
              ? (auth.user?.email ?? auth.user?.username ?? '已登录')
              : '未登录'),
            trailing: TextButton(
              onPressed: auth.isBusy
                  ? null
                  : () async {
                      await context.read<AuthController>().signOut();
                    },
              child: const Text('退出登录'),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('共享我的位置'),
            subtitle: Text(
              c.hasSyncBackend
                  ? '将本机位置实时同步到服务器'
                  : '服务器未连接，仅本地定位预览',
            ),
            value: c.sharingEnabled,
            onChanged: (v) => c.setSharingEnabled(v),
          ),
          const Divider(),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '显示名称',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => c.setDisplayName(v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await c.setDisplayName(_nameCtrl.text);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已保存')),
              );
            },
            child: const Text('保存'),
          ),
          const SizedBox(height: 24),
          Text(
            '权限',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ListTile(
            title: const Text('定位权限'),
            subtitle: Text(_permSubtitle(_locationStatus)),
            trailing: TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('去设置'),
            ),
          ),
        ],
      ),
    );
  }

  String _permSubtitle(PermissionStatus s) {
    return switch (s) {
      PermissionStatus.granted => '已授权',
      PermissionStatus.denied => '已拒绝',
      PermissionStatus.permanentlyDenied => '已永久拒绝，请到系统设置开启',
      PermissionStatus.restricted => '受限制',
      PermissionStatus.limited => '有限授权（iOS）',
      _ => s.toString(),
    };
  }
}
