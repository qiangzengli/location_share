# 配置说明（高德 + Firebase）

## 1. 高德开放平台

1. 在 [高德开放平台](https://lbs.amap.com/) 创建应用，分别申请 **Android 地图 SDK / 定位 SDK** 与 **iOS 地图 SDK / 定位 SDK** 的 Key。
2. Android：在高德控制台绑定 **包名** `com.locationshare.location_share` 与 **调试 SHA1**（及发布 SHA1）。
3. iOS：绑定 **Bundle ID**（与 Xcode `Runner` 一致，默认 `com.locationshare.locationShare`）。
4. 本工程使用 **`x_amap_flutter_location`**（pub）+ **vendored [`packages/x_amap_flutter_map`](packages/x_amap_flutter_map)**：官方 `amap_flutter_*` 3.0.0 在 Dart 3.9+ 无法编译；pub 上的 `x_amap_flutter_map` Android 仍引用已删除的 `FlutterMain` / v1 `Registrar`，因此在仓库内 vendor 并打补丁（见 [`README_VENDOR.md`](packages/x_amap_flutter_map/README_VENDOR.md)）。

### 运行应用（dart-define）

```bash
flutter run
```

Firebase 原生配置文件已接入工程，不再依赖 `dart-define` 注入 Firebase 参数。

## 2. Firebase 项目配置

1. 在 Firebase Console 创建项目。
2. 启用 **Authentication > Sign-in method > Email/Password**。
3. 启用 **Cloud Firestore**。
4. 从 Firebase Console 下载并放置原生配置文件：

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
5. 如需进一步标准化，可后续执行 `flutterfire configure` 生成官方 `lib/firebase_options.dart`，再覆盖当前文件。

应用使用：

- Firebase Auth：邮箱注册 / 登录 / 登出
- Cloud Firestore：集合 `participant_locations` 实时同步位置

推荐先使用下面的开发规则：

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /participant_locations/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 3. 定位与权限（首版）

- 首版以 **使用中（前台）** 定位为主；`AndroidManifest` 未声明后台持续定位所需的全套前台服务，以降低商店与运行时复杂度。
- 若需「离开 App 仍高频上报」，需另行：Android 前台服务 + 通知渠道、iOS `UIBackgroundModes` = `location`、并在 App Store 审核备注使用场景。

## 4. 共享组与设备标识

- 默认共享组 ID：`groups/dev_family`（可在「设置」中修改；所有测试机需一致）。
- 登录后使用 Firebase `uid` 作为 `participant_id`。
