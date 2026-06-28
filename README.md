<p align="center">
    <img width="128" src="simple_live_app/assets/logo.png" alt="Simple Live">
</p>
<h2 align="center">Simple Live + 快手</h2>

<p align="center">
基于 Simple Live 的五平台直播聚合应用，新增快手直播支持
</p>

## 项目说明

本项目基于 [June6699/dart_simple_live](https://github.com/June6699/dart_simple_live) fork，在原有四平台（哔哩哔哩、斗鱼、虎牙、抖音）的基础上，从 [PureLive](https://github.com/heartsg/pure_live) 移植了快手直播适配器，实现五平台聚合。

### 与上游项目的关系

- **基础框架**：完整保留 SimpleLive (June6699) 的架构、UI、弹幕系统、播放逻辑等
- **新增功能**：快手直播适配器（分类浏览、推荐列表、房间详情、多清晰度播放）
- **未移植功能**：快手搜索、快手弹幕（快手弹幕协议较复杂，暂为空实现）

### 技术架构

| 模块 | 说明 |
|------|------|
| `simple_live_core` | 纯 Dart 核心库，包含各平台适配器 |
| `simple_live_app` | Flutter 移动端应用 |
| `simple_live_tv_app` | Flutter TV 端应用 |
| `simple_live_console` | 命令行调试工具 |

### 快手适配器实现细节

快手适配器 (`simple_live_core/lib/src/kuaishou_site.dart`) 核心实现：

- **房间详情**：通过 HTML 抓取 `window.__INITIAL_STATE__` 获取直播间信息
- **Cookie 管理**：使用 Dio + CookieJar 自动采集 Cookie
- **DID 注册**：模拟设备注册以获取合法请求身份
- **分类数据**：8 大父分类（热门/网游/单机/手游/棋牌/娱乐/综合/文化），子分类从 API 动态获取
- **清晰度**：解析 `h264.adaptationSet.representation` 获取多码率播放地址
- **弹幕/搜索**：暂为空实现，返回默认值

## 构建

### 环境要求

- Flutter SDK >= 3.0
- Android SDK（如需构建 APK）
- Dart SDK >= 3.0

### 构建步骤

```bash
# 获取依赖
cd simple_live_app
flutter pub get

# 构建 Debug APK
flutter build apk --debug

# 构建 Release APK（推荐按 ABI 分包以减小体积）
flutter build apk --release --split-per-abi
```

### 中国大陆构建注意

- Pub 镜像：`PUB_HOSTED_URL=https://pub.flutter-io.cn`
- Flutter Storage：`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
- Gradle 分发：建议使用腾讯云镜像替换 `gradle-wrapper.properties` 中的 `distributionUrl`
- Maven：在 `settings.gradle.kts` 和 `build.gradle.kts` 中添加阿里云镜像
- media_kit：该库在构建时从 GitHub 下载 native JAR，大陆可能需要手动预下载或使用代理

## 支持的平台

| 平台 | 直播 | 弹幕 | 搜索 | 分类 | 说明 |
|------|------|------|------|------|------|
| 哔哩哔哩 | ✅ | ✅ | ✅ | ✅ | SimpleLive 内置 |
| 斗鱼 | ✅ | ✅ | ✅ | ✅ | SimpleLive 内置 |
| 虎牙 | ✅ | ✅ | ✅ | ✅ | SimpleLive 内置 |
| 抖音 | ✅ | ✅ | ✅ | ✅ | SimpleLive 内置 |
| 快手 | ✅ | ❌ | ❌ | ✅ | 从 PureLive 移植 |

## 致谢

- [xiaoyaocz/dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live) — SimpleLive 原作者
- [June6699/dart_simple_live](https://github.com/June6699/dart_simple_live) — 活跃维护的 fork 版本
- [PureLive](https://github.com/heartsg/pure_live) — 快手适配器的参考实现

## License

本项目遵循原 SimpleLive 的开源许可证。
