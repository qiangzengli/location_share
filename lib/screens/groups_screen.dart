import 'package:flutter/material.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:location_share/screens/create_group_screen.dart';
import 'package:location_share/screens/group_detail_screen.dart';
import 'package:location_share/screens/join_group_screen.dart';
import 'package:provider/provider.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<GroupController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的群组'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: '加入群组',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const JoinGroupScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const CreateGroupScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: gc.isLoading && gc.groups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : gc.groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('还没有加入任何群组',
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('创建一个新群组或通过邀请码加入',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              )),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: gc.refresh,
                  child: ListView.builder(
                    itemCount: gc.groups.length,
                    itemBuilder: (context, index) {
                      final group = gc.groups[index];
                      final isActive = group.id == gc.activeGroupId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          child: Icon(
                            Icons.group,
                            color: isActive
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                        title: Text(group.name),
                        subtitle: Text('${group.memberCount} 位成员'),
                        trailing: isActive
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  GroupDetailScreen(groupId: group.id),
                            ),
                          );
                        },
                        onLongPress: () {
                          gc.setActiveGroup(group.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('已切换到「${group.name}」')),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
