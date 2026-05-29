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

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final c = context.read<SharingController>();
    _nameCtrl = TextEditingController(text: c.displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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
            subtitle: Text(auth.user?.email ?? '未登录'),
            trailing: TextButton(
              onPressed: auth.isBusy
                  ? null
                  : () async {
                      await context.read<AuthController>().signOut();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
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
          FutureBuilder<PermissionStatus>(
            future: Permission.locationWhenInUse.status,
            builder: (context, snap) {
              final s = snap.data ?? PermissionStatus.denied;
              return ListTile(
                title: const Text('定位权限'),
                subtitle: Text(_permSubtitle(s)),
                trailing: TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('去设置'),
                ),
              );
            },
          ),
          const Divider(),
          Text(
            '配置状态',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ListTile(
            title: const Text('高德 Key'),
            subtitle: const Text('已写入 lib/config/env.dart'),
          ),
          ListTile(
            title: const Text('后端服务'),
            subtitle: Text(
              c.hasSyncBackend ? '后端已连接，认证与位置同步均可启用' : '后端未连接',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '首版说明：为降低商店审核与系统弹窗复杂度，当前以「使用中」定位为主；'
            '后台持续共享需另行申请权限并可能使用前台服务。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
