import 'package:flutter/foundation.dart';
import 'package:location_share/models/group.dart';
import 'package:location_share/repositories/group_repository.dart';
import 'package:location_share/services/local_prefs.dart';

class GroupController extends ChangeNotifier {
  GroupController({
    required GroupRepository repository,
    required LocalPrefs prefs,
  })  : _repo = repository,
        _prefs = prefs;

  final GroupRepository _repo;
  final LocalPrefs _prefs;

  List<Group> groups = [];
  String? activeGroupId;
  bool isLoading = false;
  String? error;

  Group? get activeGroup {
    if (activeGroupId == null) return null;
    try {
      return groups.firstWhere((g) => g.id == activeGroupId);
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    activeGroupId = await _prefs.getActiveGroupId();
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      groups = await _repo.myGroups();
      if (activeGroupId != null &&
          !groups.any((g) => g.id == activeGroupId)) {
        activeGroupId = groups.isNotEmpty ? groups.first.id : null;
        await _prefs.setActiveGroupId(activeGroupId);
      }
      if (activeGroupId == null && groups.isNotEmpty) {
        activeGroupId = groups.first.id;
        await _prefs.setActiveGroupId(activeGroupId);
      }
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> setActiveGroup(String groupId) async {
    activeGroupId = groupId;
    await _prefs.setActiveGroupId(groupId);
    notifyListeners();
  }

  Future<Group> createGroup(String name) async {
    final group = await _repo.createGroup(name);
    await refresh();
    activeGroupId = group.id;
    await _prefs.setActiveGroupId(group.id);
    notifyListeners();
    return group;
  }

  Future<Group> joinGroup(String inviteCode) async {
    final group = await _repo.joinGroup(inviteCode);
    await refresh();
    activeGroupId = group.id;
    await _prefs.setActiveGroupId(group.id);
    notifyListeners();
    return group;
  }

  Future<void> leaveGroup(String groupId) async {
    await _repo.leaveGroup(groupId);
    if (activeGroupId == groupId) {
      activeGroupId = null;
      await _prefs.setActiveGroupId(null);
    }
    await refresh();
  }

  Future<void> deleteGroup(String groupId) async {
    await _repo.deleteGroup(groupId);
    if (activeGroupId == groupId) {
      activeGroupId = null;
      await _prefs.setActiveGroupId(null);
    }
    await refresh();
  }

  Future<GroupDetail> groupDetail(String groupId) async {
    return _repo.groupDetail(groupId);
  }

  Future<void> kickMember(String groupId, String userId) async {
    await _repo.kickMember(groupId, userId);
  }

  Future<Group> regenerateCode(String groupId) async {
    return _repo.regenerateCode(groupId);
  }

  Future<Group> updateGroupName(String groupId, String name) async {
    final group = await _repo.updateGroup(groupId, name);
    await refresh();
    return group;
  }
}
