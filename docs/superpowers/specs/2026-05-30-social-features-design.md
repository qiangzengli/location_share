# 社交功能设计文档

## 概述

为位置共享 App 添加好友系统、家庭组系统、消息/聊天系统和位置权限控制。采用 REST API + WebSocket 实时通道架构。

## 需求摘要

- 家庭组：创建/加入（邀请码+链接），管理员踢人，成员退出
- 好友：搜索用户名/邮箱添加 + 邀请码添加，好友可直接邀请入组
- 消息：私聊 + 群聊 + 系统通知（好友请求、组邀请）
- 位置权限：默认全组可见，可一键切换，可对单个成员隐藏/显示
- 用户可同时属于多个家庭组
- 组管理权限：创建者为管理员（简单模式）

---

## 一、数据模型

### Friendship (好友关系)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID, PK | |
| user_id | UUID, FK → AppUser | 发起方 |
| friend_id | UUID, FK → AppUser | 接收方 |
| status | enum: pending/accepted/blocked | |
| created_at | timestamp | |
| updated_at | timestamp | |

唯一约束: (user_id, friend_id)

### Group (家庭组)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID, PK | |
| name | string(64) | 组名 |
| invite_code | string(8), unique | 随机邀请码 |
| owner_id | UUID, FK → AppUser | 创建者/管理员 |
| created_at | timestamp | |
| updated_at | timestamp | |

### GroupMember (组成员)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID, PK | |
| group_id | UUID, FK → Group | |
| user_id | UUID, FK → AppUser | |
| joined_at | timestamp | |

唯一约束: (group_id, user_id)

### LocationVisibility (位置可见性)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID, PK | |
| group_id | UUID, FK → Group | |
| user_id | UUID | 谁的设置 |
| target_user_id | UUID | 对谁设置 |
| visible | bool, default true | |

唯一约束: (group_id, user_id, target_user_id)

不存在记录 = 可见（默认）。仅在用户主动隐藏时创建 visible=false 记录。

### Message (消息)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID, PK | |
| type | enum: chat/friend_request/group_invite/system | |
| sender_id | UUID, FK → AppUser | |
| receiver_id | UUID, nullable | 私聊/好友请求目标 |
| group_id | UUID, nullable | 群聊目标 |
| content | text | |
| metadata | JSON | 扩展数据 (邀请码/请求ID等) |
| read | bool, default false | |
| created_at | timestamp | |

### 现有表改造

- **AppUser**: 新增 `friend_code` 字段 (string(8), unique)，用于好友邀请码
- **ParticipantLocation**: `group_id` 将关联到 Group 表，增加成员校验

---

## 二、API 端点

### 好友

```
POST   /api/friends/request              — 按用户名/邮箱发送好友请求
POST   /api/friends/request/code         — 通过邀请码加好友
POST   /api/friends/{friendshipId}/accept
POST   /api/friends/{friendshipId}/reject
DELETE /api/friends/{friendshipId}
GET    /api/friends                       — 好友列表 (accepted)
GET    /api/friends/pending               — 待处理请求
GET    /api/friends/my-code               — 获取我的好友邀请码
```

### 家庭组

```
POST   /api/groups                        — 创建组
GET    /api/groups                        — 我的组列表
GET    /api/groups/{groupId}              — 组详情+成员
PATCH  /api/groups/{groupId}              — 改名 (管理员)
DELETE /api/groups/{groupId}              — 解散 (管理员)
POST   /api/groups/join                   — 邀请码加入
POST   /api/groups/{groupId}/invite       — 邀请好友入组
POST   /api/groups/{groupId}/kick/{userId}
DELETE /api/groups/{groupId}/leave
POST   /api/groups/{groupId}/regenerate-code — (管理员)
```

### 位置可见性

```
GET    /api/groups/{groupId}/visibility
PUT    /api/groups/{groupId}/visibility           — 一键全组
PUT    /api/groups/{groupId}/visibility/{targetUserId} — 单人
```

现有 `GET /api/groups/{groupId}/locations` 增加可见性过滤。

### 消息

```
GET    /api/messages/conversations
GET    /api/messages/private/{userId}     — 分页
GET    /api/messages/group/{groupId}      — 分页
POST   /api/messages/private/{userId}
POST   /api/messages/group/{groupId}
POST   /api/messages/read                 — 批量已读
GET    /api/messages/unread-count
```

### WebSocket

```
WS /api/ws?token={accessToken}
```

---

## 三、WebSocket 协议

### 连接

- 认证: URL query param token，服务端验证 JWT，失败 close 4001
- 心跳: 客户端 30s ping，服务端 pong，60s 无响应断开
- 重连: 指数退避 1s/2s/4s/...最大 30s

### 消息格式

```json
{
  "type": "chat_message | friend_request | group_invite | member_joined | member_left | location_update",
  "payload": { ... }
}
```

### 上行 (客户端 → 服务端)

仅 `location_update`:
```json
{"type": "location_update", "payload": {"groupId": "...", "lat": 31.2, "lng": 121.4, "accuracy": 10, "heading": 0, "speed": 0}}
```

### 下行类型

| type | payload |
|------|---------|
| chat_message | messageId, senderId, senderName, content, groupId(群聊时) |
| friend_request | friendshipId, fromUser{id, displayName} |
| group_invite | groupId, groupName, inviterName, messageId |
| member_joined | groupId, user{id, displayName} |
| member_left | groupId, userId |
| location_update | groupId, participantId, displayName, lat, lng, accuracy, heading, speed |

---

## 四、Flutter 端架构

### 新增模块

```
lib/models/       — friendship.dart, group.dart, message.dart, conversation.dart
lib/services/     — websocket_service.dart (连接管理、重连、消息分发)
lib/repositories/ — friend_repository.dart, group_repository.dart, message_repository.dart
lib/providers/    — friend_controller.dart, group_controller.dart, message_controller.dart, ws_controller.dart
lib/screens/      — friends_screen.dart, friend_requests_screen.dart, groups_screen.dart,
                    group_detail_screen.dart, create_group_screen.dart, join_group_screen.dart,
                    conversations_screen.dart, chat_screen.dart
lib/widgets/      — invite_sheet.dart
```

### 现有模块改造

- **app_shell.dart**: 底部导航 5 tab: 地图/群组/消息/好友/设置
- **map_screen.dart**: 顶部组切换器
- **settings_screen.dart**: 移除手动 groupId 输入框
- **sharing_controller.dart**: 多组支持 + WS 位置上报
- **auth_controller.dart**: 登录后触发 WS 连接

### 核心流程

```
登录 → AuthController → WsController 建立 WebSocket
WS 收消息 → 按 type 分发到 FriendController / GroupController / MessageController / SharingController
位置上报: SharingController → WsController.send(location_update)
```

### 底部导航

```
[地图]  [群组]  [消息]  [好友]  [设置]
```

消息 tab 显示未读角标。

---

## 五、实施阶段

### 阶段一：家庭组系统

后端: Group, GroupMember 表 + CRUD API + 邀请码 + 成员校验
前端: 组列表、创建组、邀请码加入、组详情、地图切换组、改造现有 location API

### 阶段二：好友系统

后端: Friendship 表 + API + 用户搜索 + 好友邀请码
前端: 好友列表、搜索添加、请求处理、从好友邀请入组

### 阶段三：WebSocket + 消息系统

后端: WebSocket 管理 + Message 表 + 聊天/通知 API
前端: WS 服务、会话列表、私聊/群聊、系统通知、未读角标

### 阶段四：位置权限 + WS 位置同步

后端: LocationVisibility 表 + API + WS 位置广播
前端: 可见性设置 UI + 位置同步切 WS + REST 降级
