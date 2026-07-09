# Simple Live 纯鸿蒙 NEXT 原生播放器迁移说明

目标：在不删除现有 Android/iOS/桌面播放栈的前提下，新增纯鸿蒙 NEXT/OpenHarmony 目标。普通 `pubspec.yaml` 继续使用原 `media_kit`；鸿蒙构建时临时使用 `pubspec.ohos.yaml`，通过本地同名 shim 包把现有 `media_kit` API 转接到 ArkUI `XComponent` + `@ohos.multimedia.media.AVPlayer` + Flutter PlatformView。

## 已新增结构

```text
lib/services/native_player/native_player.dart      # Dart 极简播放器抽象 + MethodChannel + PlatformView Widget
lib/services/fake_chewie/fake_chewie.dart          # Chewie 兼容外观封装
pubspec.ohos.yaml                                  # OHOS NEXT 专用依赖，media_kit/media_kit_video 指向本地兼容 shim
third_party/ohos_media_kit_compat/media_kit/       # OHOS 专用 media_kit API 兼容包
third_party/ohos_media_kit_compat/media_kit_video/ # OHOS 专用 media_kit_video API 兼容包
.github/actions/setup-flutter-ohos/action.yml      # GitHub Actions: Flutter OHOS + OHOS SDK 初始化
.github/workflows/publish_app_release_ohos.yml     # GitHub Actions: 手动构建 .hap
ohos/                                               # DevEco Studio OHOS 工程骨架
  build-profile.json5
  hvigorfile.ts
  oh-package.json5
  entry/
    build-profile.json5
    oh-package.json5
    src/main/module.json5
    src/main/ets/entryability/EntryAbility.ets
    src/main/ets/nativeplayer/OhosNativePlayerPlugin.ets
    src/main/ets/nativeplayer/OhosNativePlayerRegistry.ets
    src/main/ets/nativeplayer/OhosNativePlayerView.ets
    src/main/cpp/CMakeLists.txt
    src/main/cpp/napi_init.cpp
```

## Dart 接入

### 1. 播放控制抽象

`SimpleLivePlayerController` 只暴露：

- `play(String url)`
- `pause()`
- `seek(Duration position)`
- `getProgress()`
- `fullscreen()`
- `exitFullscreen()`
- `setVolume(double value)`
- `stop()` / `dispose()`

OHOS 使用 `OhosNativePlayerController`，事件从原生回传：`playing`、`paused`、`buffering`、`completed`、`error`。

### 2. Chewie 兼容层

如果后续页面使用 chewie，只需要把：

```dart
import 'package:chewie/chewie.dart';
```

替换成：

```dart
import 'package:simple_live_app/services/fake_chewie/fake_chewie.dart';
```

然后把原 `VideoPlayerController` 换成 `OhosNativePlayerController`。当前仓库实际使用的是 `media_kit`，所以后续主线替换点不是 chewie，而是：

- `lib/modules/live_room/player/player_controller.dart`
- `lib/modules/live_room/live_room_controller.dart`
- `lib/modules/live_room/live_room_page.dart`
- `lib/modules/live_room/player/player_controls.dart`
- `lib/modules/multi_room/multi_room_player_controller.dart`
- `lib/modules/multi_room/multi_room_page.dart`
- `lib/services/mpv_options_service.dart`
- `lib/services/live_subtitle_service.dart`

### 3. 推荐渐进替换策略

1. 保留现有 Android/iOS/桌面 `media_kit` 逻辑。
2. 新增 `isOhosRuntime` 分支：OHOS 创建 `OhosNativePlayerController`，其他平台仍走 `media_kit`。
3. 先替换主直播间播放器，再替换多开同屏。
4. `live_subtitle_service.dart` 仍依赖 `media_kit` 做音频解码，OHOS 先禁用实时音频采集，避免把播放和识别两条管线绑死。
5. OHOS 构建只在 CI/本地构建时临时把 `pubspec.ohos.yaml` 覆盖为 `pubspec.yaml`；不要提交覆盖后的主 `pubspec.yaml`，原平台继续保留 `media_kit*`。

## OHOS Native 设计

### PlatformView

- viewType：`simple_live/ohos_native_player`
- Dart Widget：`OhosNativePlayerView`
- Native Factory：`OhosNativePlayerFactory`
- Native View：`OhosNativePlayerView`

### MethodChannel

Channel：`simple_live/ohos_native_player`

Dart -> ArkTS：

- `play` `{ viewId, url }`
- `pause` `{ viewId }`
- `seek` `{ viewId, position }`
- `getProgress` `{ viewId }`
- `fullscreen` `{ viewId }`
- `exitFullscreen` `{ viewId }`
- `setVolume` `{ viewId, volume }`
- `stop` `{ viewId }`
- `dispose` `{ viewId }`

ArkTS -> Dart：

- `event` `{ viewId, state, progress, message }`

### AVPlayer 管线

`OhosNativePlayerView.ets` 使用：

- `media.createAVPlayer()` 创建系统播放器
- `avPlayer.url = url` 下发 HLS/m3u8/FLV 直链
- `prepare()` -> `play()`
- `stateChange`、`timeUpdate`、`durationUpdate`、`bufferingUpdate`、`error` 回传给 Dart
- `pauseAllForBackground()` / `resumeForegroundPlayers()` 处理前后台生命周期
- `enterFullscreen()` / `exitFullscreen()` 处理沉浸式全屏、横屏和系统栏

## DevEco Studio 接入步骤

1. 安装 DevEco Studio NEXT 和 OpenHarmony SDK。
2. 使用 Flutter OHOS TPC 分支初始化 Flutter OHOS 环境。
3. 把 Flutter OHOS 产物中的 `flutter.har` 放到：

```text
ohos/har/flutter.har
```

实际目录应为：

```text
simple_live_app/ohos/har/flutter.har
```

4. 在本地构建鸿蒙时，临时用 `pubspec.ohos.yaml` 覆盖 `pubspec.yaml`；CI 会自动完成这一步。
5. 用 DevEco Studio 打开 `simple_live_app/ohos`。
6. 同步 hvigor 依赖。
7. 真机选择 OpenHarmony NEXT 设备，构建 entry 模块。

## HAP 构建命令

在 `simple_live_app/ohos` 目录执行：

```bash
hvigorw assembleHap --mode module -p module=entry@default -p product=default
```

或 DevEco Studio：

```text
Build > Build Hap(s)/APP(s) > Build Hap(s)
```

输出通常位于：

```text
simple_live_app/ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

## 注意事项

- 当前仓库没有 chewie/video_player，实际播放栈是 `media_kit`。
- `pubspec.ohos.yaml` 是 OHOS 目标配置，使用本地 `media_kit` shim；不要把它永久覆盖提交到主 `pubspec.yaml`。
- OHOS PlatformView API 随 Flutter OHOS TPC 分支变化较快，DevEco 首次打开后需要按当前 TPC 分支校正 `@ohos/flutter_ohos` 的 import/type 名称。
- `OhosNativePlayerView.ets` 中的 ArkUI `XComponent` 负责提供原生 Surface，`AVPlayer` 负责硬解和 HLS；如果当前 SDK 要求显式绑定 surfaceId，需要在 `prepare()` 前补一行当前 SDK 对应的 `surfaceId` 赋值。
## GitHub Actions

已新增两个入口：

- `.github/workflows/publish_app_release_ohos.yml`：手动构建鸿蒙 `.hap`，可选择上传到 Release。
- `.github/workflows/release.yml`：中央 Release 流程已增加 `ohos` job，tag release 时会一起收集 `.hap` 并上传。

GitHub 官方 runner 不内置 DevEco/OpenHarmony SDK，仓库需要配置：

- `OHOS_SDK_URL`：推荐配置，放在 Repository Secret 或 Variable，值为可下载的 OpenHarmony/HarmonyOS command-line SDK zip；未配置时 workflow 会尝试 Flutter OHOS/hvigor 默认工具链，但不同 runner 很可能仍会在真正构建 HAP 时提示缺 SDK。
- `FLUTTER_OHOS_REPO`：可选，默认 `https://gitee.com/openharmony-sig/flutter_flutter.git`。
- `FLUTTER_OHOS_REF`：可选，指定 Flutter OHOS TPC 分支/标签/commit；留空使用仓库默认分支。
- `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL`：可选，网络慢时配置镜像。

手动触发路径：

```text
Actions > app-build-ohos-release > Run workflow
```

产物：

```text
simple_live_app/build/ohos-artifacts/*.hap
```