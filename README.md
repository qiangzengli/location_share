# location_share

基于 Flutter 的位置共享应用。当前已接入：

- Firebase Authentication：邮箱注册、登录、登出、用户昵称管理
- 高德地图 / 定位：地图展示与本机定位
- Cloud Firestore：位置实时同步与同组成员位置订阅

## 推荐接入方式

项目代码已经改成 Firebase 原生配置 + FlutterFire 代码接入结构：

- Dart 入口使用 `firebase_options.dart`
- Android 已接入 `com.google.gms.google-services`
- iOS 已接入 `GoogleService-Info.plist` 和 `FirebaseApp.configure()`

当前仓库已经放入真实原生 Firebase 配置文件：

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

## Firebase 登录配置

当前项目无需再通过 `--dart-define` 传 Firebase 参数。

## Firestore 数据结构

应用会读写集合：

```text
participant_locations/{urlEncodedGroupId}_{uid}
```

文档字段包括：

- `groupId`
- `participantId`
- `displayName`
- `latitude`
- `longitude`
- `accuracy`
- `heading`
- `speed`
- `updatedAt`
- `platform`

## Firestore 规则建议

至少保证已登录用户才能读写位置。开发阶段可先用：

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

如果你要更严格的按组隔离，可以下一步再把 group membership 做进用户资料或自定义 claims。

## 批量图片生成脚本

仓库内提供了顺序生成图片的脚本：

`scripts/generate_images.py`

用途：

- 按编号顺序生成并保存图片
- 失败自动重试
- 支持断点续跑
- 生成记录写入 `manifest.jsonl`

使用前先设置环境变量：

```bash
export OPENAI_API_KEY="你的 OpenAI API Key"
```

示例：

```bash
python3 scripts/generate_images.py \
  --count 1000 \
  --out-dir generated_images/chinese_beauty_batch
```

如果要改提示词：

```bash
python3 scripts/generate_images.py \
  --count 1000 \
  --prompt "你的提示词"
```
