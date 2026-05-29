import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location_share/models/group.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  GroupDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _detail =
          await context.read<GroupController>().groupDetail(widget.groupId);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final myUserId = auth.user?.uid;
    final isOwner = _detail != null && _detail!.ownerId == myUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.name ?? '群组详情'),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (v) => _onMenu(v, context),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('修改名称')),
                const PopupMenuItem(
                    value: 'regen', child: Text('重新生成邀请码')),
                const PopupMenuItem(value: 'delete', child: Text('解散群组')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(context, isOwner, myUserId),
    );
  }

  Widget _buildContent(BuildContext context, bool isOwner, String? myUserId) {
    final detail = _detail!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('邀请码',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          detail.inviteCode,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制邀请码',
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: detail.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('邀请码已复制')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    tooltip: '显示二维码',
                    onPressed: () => _showQrDialog(context, detail.inviteCode),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('成员 (${detail.members.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...detail.members.map((m) => ListTile(
                leading: CircleAvatar(
                    child: Text(m.displayName.isNotEmpty
                        ? m.displayName[0]
                        : '?')),
                title: Text(m.displayName),
                subtitle: Text(m.username),
                trailing: _memberTrailing(m, isOwner, myUserId, detail.ownerId),
              )),
          const SizedBox(height: 24),
          if (!isOwner)
            OutlinedButton(
              onPressed: () => _leaveGroup(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('退出群组'),
            ),
        ],
      ),
    );
  }

  Widget? _memberTrailing(
      GroupMember m, bool isOwner, String? myUserId, String ownerId) {
    if (m.userId == ownerId) {
      return const Chip(label: Text('管理员'));
    }
    if (isOwner && m.userId != myUserId) {
      return IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        color: Theme.of(context).colorScheme.error,
        tooltip: '踢出',
        onPressed: () => _kickMember(context, m),
      );
    }
    return null;
  }

  Future<void> _kickMember(BuildContext context, GroupMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认踢出'),
        content: Text('确定要将「${m.displayName}」移出群组吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context
        .read<GroupController>()
        .kickMember(widget.groupId, m.userId);
    _load();
  }

  Future<void> _leaveGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出后将无法查看该群组的位置信息。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<GroupController>().leaveGroup(widget.groupId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onMenu(String action, BuildContext context) async {
    final gc = context.read<GroupController>();
    switch (action) {
      case 'rename':
        final ctrl = TextEditingController(text: _detail?.name);
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('修改名称'),
            content: TextField(
                controller: ctrl,
                decoration:
                    const InputDecoration(border: OutlineInputBorder())),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: const Text('确认')),
            ],
          ),
        );
        ctrl.dispose();
        if (name != null && name.trim().isNotEmpty) {
          await gc.updateGroupName(widget.groupId, name.trim());
          _load();
        }
      case 'regen':
        await gc.regenerateCode(widget.groupId);
        _load();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认解散'),
            content: const Text('解散后所有成员将被移出，此操作不可撤销。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('解散',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          await gc.deleteGroup(widget.groupId);
          if (mounted) Navigator.of(context).pop();
        }
    }
  }

  void _showQrDialog(BuildContext context, String inviteCode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请二维码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              color: Colors.white,
              child: QrImageView(data: inviteCode, size: 200),
            ),
            const SizedBox(height: 12),
            Text(inviteCode,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    )),
            const SizedBox(height: 4),
            const Text('让对方扫描此二维码加入群组',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}
