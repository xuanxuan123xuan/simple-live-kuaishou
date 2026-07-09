# Simple Live

Simple Live 是一个跨平台聚合直播客户端，目标是用统一体验观看多个直播平台：浏览、搜索、播放、弹幕、关注、历史、多开和设置同步尽量集中到一个应用里。

本仓库基于上游 Simple Live 持续维护，当前重点维护 `simple_live_app`，同时保留 `simple_live_core`、控制台调试工具和 TV 端代码。TV 版不是当前主要适配目标。

## 功能概览

- 多平台直播浏览、搜索、播放与弹幕。
- 直播分类、推荐、主播搜索、直播间搜索和多清晰度线路切换。
- 关注列表、标签分组、开播状态刷新、观看历史和导入导出。
- 播放页支持弹幕、全屏、手势控制、音量/亮度调节、小窗播放、播放信息查看和直播间设置。
- 弹幕支持关键词屏蔽、用户屏蔽、重复弹幕去重、重点动态聚合和全屏重点动态提示。
- 账号管理支持哔哩哔哩、抖音、快手等平台的 Cookie / Web 登录能力。
- 数据同步支持本地同步、远程同步、WebDAV 和配置备份恢复。
- 构建工作流覆盖 Android、iOS、Windows、macOS、Linux，并新增 OpenHarmony / HarmonyOS NEXT HAP 构建骨架。

## 直播平台支持

| 平台 | 浏览/推荐 | 搜索 | 播放 | 弹幕 | 账号/Cookie |
| --- | --- | --- | --- | --- | --- |
| 哔哩哔哩直播 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 斗鱼直播 | ✅ | ✅ | ✅ | ✅ | - |
| 虎牙直播 | ✅ | ✅ | ✅ | ✅ | - |
| 抖音直播 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 快手直播 | ✅ | ✅ | ✅ | ✅ | ✅ |

> 各直播平台页面结构、接口策略和风控规则可能随时变化。若出现搜索失败、Cookie 失效、直播状态误判或弹幕异常，通常需要按平台单独适配。

## 应用能力

### 直播与播放

- 首页聚合展示多平台分类、推荐和关注状态。
- 直播间支持清晰度、线路、播放比例、硬解偏好、后台播放和播放信息查看。
- 支持 Android / iOS 移动端体验，也支持 Windows / macOS / Linux 桌面端构建。
- 桌面端支持多开窗口，多房间同屏观看。
- 播放器保留现有 `media_kit` 播放栈；鸿蒙 NEXT 目标新增原生 ArkUI/AVPlayer 兼容方案，不影响其它平台。

### 弹幕与互动

- 各平台弹幕协议在 `simple_live_core` 中统一封装。
- 支持弹幕显示、屏蔽、去重、颜色/用户名解析和重点动态聚合。
- 重点动态仅处理本地已收到的弹幕，不会额外请求平台接口，也不会额外消耗 Cookie。
- 弹幕设置可按平台管理关键词、用户名和全平台规则。

### 账号与 Cookie

- 哔哩哔哩支持 Web 登录和二维码登录。
- 抖音支持 Web 登录、完整 Cookie 粘贴、登录态提示和有效期估算。
- 快手支持 Web 登录、完整 Cookie / Request Headers 粘贴、文件导入、导出和有效期估算。
- Cookie 可能因退出登录、修改密码、设备变化或平台风控提前失效，请勿公开分享 Cookie、token 或导出的账号文件。

### 数据与同步

- 支持关注、标签、观看历史、弹幕屏蔽词和设置项导入导出。
- 支持局域网同步、远程同步和 WebDAV 配置备份。
- 支持配置包备份恢复，方便多设备迁移。

## OpenHarmony / HarmonyOS NEXT

仓库新增了鸿蒙 NEXT 支持骨架，目标是 **不删除原有 Android/iOS/桌面播放栈**，而是为鸿蒙单独接入原生播放能力：

- Flutter 业务 UI、直播列表、路由、解析、弹幕和缓存逻辑尽量复用。
- 鸿蒙构建使用 `simple_live_app/pubspec.ohos.yaml`，其中 `media_kit` / `media_kit_video` 指向本地兼容 shim。
- 原生侧使用 ArkUI `XComponent`、Flutter PlatformView、MethodChannel 和 `@ohos.multimedia.media.AVPlayer`。
- GitHub Actions 新增 `app-build-ohos-release`，中央 `release` workflow 也会尝试构建 `.hap`。

相关文件：

| 路径 | 说明 |
| --- | --- |
| `simple_live_app/ohos` | DevEco Studio / OHOS 工程骨架 |
| `simple_live_app/pubspec.ohos.yaml` | 鸿蒙专用依赖配置 |
| `third_party/ohos_media_kit_compat` | 鸿蒙专用 `media_kit` 兼容 shim |
| `.github/actions/setup-flutter-ohos` | GitHub Actions 中初始化 Flutter OHOS / OHOS SDK |
| `.github/workflows/publish_app_release_ohos.yml` | 手动构建 `.hap` 的 workflow |

GitHub 官方 runner 不内置 DevEco / OHOS SDK。若要在 GitHub Actions 构建 `.hap`，必须在仓库 `Settings → Secrets and variables → Actions` 中配置：

```text
OHOS_SDK_URL = 可直接下载的 OpenHarmony/HarmonyOS command-line SDK archive 链接
```

`OHOS_SDK_URL` 支持单个 `.zip` / `.tar.gz` 链接，也支持空格或换行分隔的分卷 `.tar.gz.aa`、`.tar.gz.ab` 链接。当前项目默认以 `compatibleSdkVersion: 5.0.0(12)` 构建，可使用 OpenHarmony 5.0.0 Linux SDK 分卷：

```text
https://github.com/openharmony-rs/ohos-sdk/releases/download/v5.0.0/ohos-sdk-windows_linux-public.tar.gz.aa https://github.com/openharmony-rs/ohos-sdk/releases/download/v5.0.0/ohos-sdk-windows_linux-public.tar.gz.ab
```

workflow 会额外下载公开的 `oh-command-line-tools-20240715.zip` 以提供 `ohpm`，并会展开 OpenHarmony Public SDK 里的组件 zip、补齐 Flutter OHOS 识别所需的 `sdk-pkg.json`、自动探测真实 `HOS_SDK_HOME`，再由 `ohpm install` 安装 OHOS 工程里的 hvigor 依赖。

Flutter OHOS TPC 工具链默认使用 GitCode 源：

```text
FLUTTER_OHOS_REPO = https://gitcode.com/openharmony-sig/flutter_flutter.git
FLUTTER_OHOS_REF  = 3.22.4-ohos-1.1.3
```

该分支同时具备 Dart 3 兼容性和 OHOS `flutter build hap` / `flutter build har` 支持；如果使用旧 Gitee `master` / `dev`，容易退回 Dart 2.19，导致项目 Dart SDK 约束解析失败。

未配置时 workflow 会在初始化阶段直接失败并提示配置 `OHOS_SDK_URL`。这是刻意设计：避免 GitHub runner 缺少真实 `ohpm` / `hvigorw` / OpenHarmony SDK 时继续执行，产生误导性的构建错误。

更多细节见：`simple_live_app/OHOS_NATIVE_PLAYER_MIGRATION.md`。

## 下载与自动构建

仓库 GitHub Actions 支持以下产物：

- Android APK
- iOS unsigned IPA
- Windows ZIP
- macOS DMG / ZIP
- Linux DEB / ZIP
- OpenHarmony / HarmonyOS NEXT HAP

主要 workflow：

| Workflow | 说明 |
| --- | --- |
| `release` | tag 或手动触发的综合 Release 构建 |
| `app-build-android-release` | Android APK |
| `app-build-ios-manual` | iOS unsigned IPA |
| `app-build-windows-release` | Windows 包 |
| `app-build-macos-manual` | macOS 包 |
| `app-build-linux-release` | Linux 包 |
| `app-build-ohos-release` | OpenHarmony / HarmonyOS NEXT HAP |

## 本地开发环境

推荐环境：

- Flutter SDK，需满足 `simple_live_app/pubspec.yaml` 的 Dart SDK 约束。
- Android SDK / Android Studio，用于 Android 构建。
- Xcode，用于 iOS / macOS 构建。
- Visual Studio 2022 C++ 工具链，用于 Windows 构建和部分原生依赖测试。
- DevEco Studio + OpenHarmony / HarmonyOS SDK，用于鸿蒙构建。

获取依赖：

```bash
cd simple_live_core
dart pub get

cd ../simple_live_app
flutter pub get
```

## 本地构建

### Android

```bash
cd simple_live_app
flutter build apk --release
```

### iOS

```bash
cd simple_live_app
flutter build ios --release --no-codesign
```

完整签名 IPA 需要 macOS、Xcode 和有效证书。

### Windows

```bash
cd simple_live_app
flutter build windows --release
```

### Linux

```bash
cd simple_live_app
flutter build linux --release
```

### macOS

```bash
cd simple_live_app
flutter build macos --release
```

### OpenHarmony / HarmonyOS NEXT

本地鸿蒙构建需要 GitCode Flutter OHOS TPC `3.22.4-ohos-1.1.3`、DevEco / OHOS SDK，并确保 `ohpm` / `hvigorw` / SDK toolchains 已加入环境变量。构建前临时使用鸿蒙依赖配置：

```bash
cd simple_live_app
cp pubspec.yaml pubspec.default.yaml
cp pubspec.ohos.yaml pubspec.yaml
flutter pub get
flutter build hap --release --dart-define=TARGET_OHOS=true
```

如果当前 Flutter OHOS SDK 不支持 `flutter build hap`，可进入 `simple_live_app/ohos` 使用 hvigor 构建：

```bash
cd simple_live_app/ohos
ohpm install
hvigorw assembleHap --mode module -p module=entry@default -p product=default
```

构建完成后记得恢复主配置：

```bash
cd simple_live_app
mv pubspec.default.yaml pubspec.yaml
```

## 项目结构

| 目录 | 说明 |
| --- | --- |
| `simple_live_core` | 各平台接口、直播间解析、播放地址解析和弹幕协议 |
| `simple_live_app` | Flutter 主应用，覆盖移动端、桌面端和鸿蒙适配骨架 |
| `simple_live_console` | 核心接口调试工具 |
| `simple_live_tv_app` | TV 应用代码，当前不是主要维护目标 |
| `third_party` | 本地第三方补丁、弹幕组件和鸿蒙兼容 shim |
| `.github/workflows` | 自动构建与 Release 工作流 |

## 开发验证

```bash
# Core 静态分析
cd simple_live_core
dart analyze

# Core 测试
dart test

# App 静态分析
cd ../simple_live_app
flutter analyze
```

部分环境下 `dart_quickjs`、桌面播放器或鸿蒙工具链会依赖本机原生编译器 / SDK。若分析或构建卡在原生依赖，请先确认对应平台工具链是否完整。

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)。

## 上游与参考

- [xiaoyaocz/dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live) — Simple Live 原始项目
- [June6699/dart_simple_live](https://github.com/June6699/dart_simple_live) — 本仓库采用的上游维护基础
- [heartsg/pure_live](https://github.com/heartsg/pure_live) — 直播平台适配参考
- [OrdinaryRoad-Project/ordinaryroad-barrage-fly](https://github.com/OrdinaryRoad-Project/ordinaryroad-barrage-fly) — 弹幕协议参考
- [wushuaihua520/BarrageGrab](https://github.com/wushuaihua520/BarrageGrab) — 多平台弹幕项目参考

## 许可

项目沿用仓库中的 [LICENSE](LICENSE)。使用、修改或分发前请同时遵守各直播平台的服务条款与当地法律法规。
