# Location Share — 用户登录后端（Spring Boot）

与 Flutter 客户端配合的 **REST 鉴权服务**：注册、登录、JWT 访问令牌、刷新令牌轮换、登出、修改密码、当前用户资料。

## 运行

```bash
cd backend
mvn spring-boot:run
```

默认 `http://localhost:8080`，数据落在 `backend/data/`（H2 文件库）。

- **PostgreSQL**：`mvn spring-boot:run -Dspring-boot.run.profiles=postgres`，并设置 `DATABASE_URL` / `DATABASE_USER` / `DATABASE_PASSWORD`（见 `application.yml`）。

## 环境变量（生产必改）

| 变量 | 说明 |
|------|------|
| `JWT_SECRET` | HS256 密钥，**至少 32 字节** |
| `JWT_ACCESS_MINUTES` | Access Token 有效期（分钟），默认 15 |
| `JWT_REFRESH_DAYS` | Refresh Token 有效期（天），默认 14 |

## HTTP 接口

除特别声明外，请求/响应体均为 `application/json`。

### 健康检查

`GET /api/health` → `{"status":"UP"}`

### 注册

`POST /api/auth/register`

```json
{
  "username": "alice",
  "password": "password12",
  "email": "a@b.com",
  "displayName": "Alice"
}
```

`email`、`displayName` 可选；用户名在服务端存为小写。响应示例：

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": "uuid",
    "username": "alice",
    "email": "a@b.com",
    "displayName": "Alice",
    "createdAt": "2026-05-04T12:00:00Z"
  }
}
```

### 登录

`POST /api/auth/login`

```json
{ "username": "alice", "password": "password12" }
```

响应同注册（含新令牌对）。

### 刷新令牌

`POST /api/auth/refresh`

```json
{ "refreshToken": "<refreshToken>" }
```

每次成功刷新会 **吊销旧 refresh** 并签发新的一对令牌（轮换）。

### 登出（当前设备）

`POST /api/auth/logout`

```json
{ "refreshToken": "<refreshToken>" }
```

`204 No Content`

### 登出（所有设备）

`POST /api/auth/logout-all`

请求头：`Authorization: Bearer <accessToken>`

`204 No Content`，吊销该用户全部有效 refresh。

### 修改密码

`POST /api/auth/change-password`

请求头：`Authorization: Bearer <accessToken>`

```json
{ "currentPassword": "password12", "newPassword": "newpass123" }
```

`204 No Content`；成功后 **吊销全部 refresh**（需重新登录或再次刷新，视客户端实现而定）。当前 access 在过期前仍有效，高安全场景可缩短 access 有效期。

### 当前用户

`GET /api/users/me`

请求头：`Authorization: Bearer <accessToken>`

### 更新资料

`PATCH /api/users/me`

请求头：`Authorization: Bearer <accessToken>`

```json
{ "displayName": "新昵称", "email": "new@mail.com" }
```

字段均可省略；`email` 传空字符串表示清空邮箱。

### 分组位置（需登录）

与客户端 `ParticipantLocation` 字段对齐；`groupId` 为路径参数（URL 编码），全组成员使用 **相同的 groupId** 即共享同一批位置。

#### 拉取组内全部位置

`GET /api/groups/{groupId}/locations`

请求头：`Authorization: Bearer <accessToken>`

响应：`LocationResponse[]`（JSON 数组，camelCase），示例：

```json
[
  {
    "groupId": "groups/dev_family",
    "participantId": "uuid-device",
    "displayName": "我",
    "latitude": 31.2304,
    "longitude": 121.4737,
    "accuracy": 12.5,
    "heading": null,
    "speed": null,
    "updatedAt": "2026-05-04T12:00:00Z",
    "platform": "android",
    "ownerUserId": "550e8400-e29b-41d4-a716-446655440000"
  }
]
```

#### 上传 / 更新我的位置

`PUT /api/groups/{groupId}/locations/me`

请求头：`Authorization: Bearer <accessToken>`

```json
{
  "participantId": "与客户端设备 participantId 一致",
  "latitude": 31.2304,
  "longitude": 121.4737,
  "displayName": "可选，默认用账号昵称",
  "accuracy": 12.0,
  "heading": 90.0,
  "speed": 0.0,
  "platform": "android"
}
```

- 按 `(groupId, participantId)` 幂等更新；**首次**写入会记录 `ownerUserId` 为当前登录用户。
- 若该 `participantId` 已被其他用户占用，返回 **403**（防止篡改他人设备位）。

## 与 Flutter 客户端对接说明

- 受保护接口在请求头携带：`Authorization: Bearer <accessToken>`。
- Access 过期后用 `POST /api/auth/refresh` 换新令牌对并持久化 **新的** `refreshToken`。
- Flutter 需配置 `--dart-define=API_BASE_URL=http://<host>:8080`，使用 **HTTP 轮询**（约 2s）同步位置；access token 可用 `--dart-define=API_ACCESS_TOKEN=...` 或 `LocalPrefs.setBackendAccessToken`（登录页接入后可写入）。

## 错误格式

校验失败等业务错误返回 JSON，例如：

```json
{
  "timestamp": "...",
  "status": 400,
  "error": "Bad Request",
  "message": "请求参数无效",
  "details": { "password": "size must be between 8 and 128" }
}
```
