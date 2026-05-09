# 配置说明（高德 + Spring Boot）

## 1. 高德开放平台

1. 在 [高德开放平台](https://lbs.amap.com/) 创建应用，分别申请 **Android 地图 SDK / 定位 SDK** 与 **iOS 地图 SDK / 定位 SDK** 的 Key。
2. Android：在高德控制台绑定 **包名** `com.locationshare.location_share` 与 **调试 SHA1**（及发布 SHA1）。
3. iOS：绑定 **Bundle ID**（与 Xcode `Runner` 一致，默认 `com.locationshare.locationShare`）。
4. 本工程使用 **`x_amap_flutter_location`**（pub）+ **vendored [`packages/x_amap_flutter_map`](packages/x_amap_flutter_map)**：官方 `amap_flutter_*` 3.0.0 在 Dart 3.9+ 无法编译；pub 上的 `x_amap_flutter_map` Android 仍引用已删除的 `FlutterMain` / v1 `Registrar`，因此在仓库内 vendor 并打补丁（见 [`README_VENDOR.md`](packages/x_amap_flutter_map/README_VENDOR.md)）。

### 运行应用（dart-define）

```bash
flutter run \
  --dart-define=API_BASE_URL=http://<你的电脑IP>:8080 \
  --dart-define=API_ACCESS_TOKEN=<登录后 accessToken>
```

Android 模拟器访问本机后端可使用 `http://10.0.2.2:8080`。也可用 `--dart-define-from-file=tool/dart_defines.json`（勿把真实 token 提交到 Git）。

## 2. Spring Boot 后端

1. 在 `backend/` 目录执行 `mvn spring-boot:run`，默认监听 `8080`。
2. 先调用 `POST /api/auth/register` 或 `POST /api/auth/login` 获取 JWT（详见 [`backend/README.md`](backend/README.md)）。
3. 客户端将 `accessToken` 通过 `API_ACCESS_TOKEN` 注入，或在应用内登录后写入 `LocalPrefs.setBackendAccessToken`（待接入登录页）。

位置同步走 HTTP：`PUT /api/groups/{groupId}/locations/me` 上传、`GET /api/groups/{groupId}/locations` 拉取（客户端约每 2 秒轮询）。

## 3. 定位与权限（首版）

- 首版以 **使用中（前台）** 定位为主；`AndroidManifest` 未声明后台持续定位所需的全套前台服务，以降低商店与运行时复杂度。
- 若需「离开 App 仍高频上报」，需另行：Android 前台服务 + 通知渠道、iOS `UIBackgroundModes` = `location`、并在 App Store 审核备注使用场景。

## 4. 共享组与设备标识

- 默认共享组 ID：`groups/dev_family`（可在「设置」中修改；所有测试机需一致）。
- 每台设备首次启动生成 **UUID** 作为 `participant_id`，保存在 `SharedPreferences`。
