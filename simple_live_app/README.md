# simple_live_app

`simple_live_app` 是 Simple Live 的 Flutter 主应用，负责移动端、桌面端和鸿蒙适配入口。

## 主要能力

- 聚合哔哩哔哩、斗鱼、虎牙、抖音、快手等直播平台。
- 提供直播浏览、搜索、播放、弹幕、关注、历史和同步功能。
- 默认平台继续使用现有 `media_kit` 播放栈。
- OpenHarmony / HarmonyOS NEXT 使用 `pubspec.ohos.yaml` 和本地兼容 shim 接入原生 AVPlayer 播放骨架。

## 常用命令

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

鸿蒙构建细节见仓库根目录 `README.md` 和 `OHOS_NATIVE_PLAYER_MIGRATION.md`。
