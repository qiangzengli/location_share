class Group {
  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;
  final int memberCount;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.memberCount,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['inviteCode'] as String,
      ownerId: json['ownerId'] as String,
      memberCount: json['memberCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GroupDetail {
  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;
  final List<GroupMember> members;
  final DateTime createdAt;

  GroupDetail({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.members,
    required this.createdAt,
  });

  factory GroupDetail.fromJson(Map<String, dynamic> json) {
    return GroupDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['inviteCode'] as String,
      ownerId: json['ownerId'] as String,
      members: (json['members'] as List<dynamic>)
          .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GroupMember {
  final String userId;
  final String username;
  final String displayName;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
}
