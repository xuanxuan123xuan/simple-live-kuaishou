# Simple Live + 快手

跨平台聚合直播客户端，基于 Simple Live 持续维护，在哔哩哔哩、斗鱼、虎牙、抖音之外补充了完整的快手直播支持。

## 功能概览

- 五平台直播浏览、搜索、播放与弹幕
- 快手分类、推荐、主播搜索、直播间搜索和多清晰度播放
- 快手 Web 登录、手动 Cookie 导入及 `kwfv1`/Kww 自动处理
- 快手 protobuf WebSocket 弹幕、心跳、gzip 解压和备用线路重连
- Cookie 到期时间提示、服务器 Cookie 自动刷新合并
- 直播状态多源容错，降低“正在直播却显示未开播”的误判
- 弹幕屏蔽、去重、重点动态聚合和全屏重点动态提示
- Android、iOS、Windows GitHub Actions 构建

## 平台支持

| 平台 | 直播 | 弹幕 | 搜索 | 分类/推荐 |
| --- | --- | --- | --- | --- |
| 哔哩哔哩 | ✅ | ✅ | ✅ | ✅ |
| 斗鱼 | ✅ | ✅ | ✅ | ✅ |
| 虎牙 | ✅ | ✅ | ✅ | ✅ |
| 抖音 | ✅ | ✅ | ✅ | ✅ |
| 快手 | ✅ | ✅ | ✅ | ✅ |

## 快手支持

### 浏览与播放

- 动态获取直播分类和推荐列表
- 搜索直播间与主播
- 从直播页解析播放信息和清晰度列表
- 支持 H.264 多码率播放地址
- 列表与搜索优先使用直播 `caption`，详情字段缺失时按可用信息回退
- 匿名详情优先、登录 Cookie 详情回退
- 当状态字段失真时，使用直播流 ID 与有效播放地址辅助判断开播状态

### 弹幕

- 解析快手 WebSocket protobuf 数据
- 支持评论弹幕与用户名、颜色解析
- 支持 gzip 压缩消息
- 支持心跳、备用 WebSocket 地址和自动重连
- 自动携带直播间 token、stream ID、page ID、Cookie 与浏览器请求头

### 登录与 Cookie

移动端可在“账号管理 → 快手直播”进入快手网页登录，也可以手动粘贴完整 Cookie 或 Request Headers。

- Android/iOS 内置 WebView 登录入口
- 自动读取 Cookie 与 localStorage 中的 `kwfv1`
- 手动输入不要求额外填写 Kww
- 展示可读取到的登录凭证预计剩余有效期
- 服务器返回的新 Cookie 会覆盖旧值，避免短期 `web_st` 无法续期
- 无法可靠取得到期时间时明确显示“有效期无法判断”

> Cookie 可能因退出登录、修改密码或平台风控提前失效。请勿公开分享 Cookie、token 或导出的账号文件。

## 弹幕增强

- 关键词和用户屏蔽
- 重复弹幕去重
- 重点动态：在本地统计短时间内重复出现的弹幕
- 可配置统计跨度、起显次数、展示时间和保留数量
- 可在全屏播放器中显示重点动态

重点动态仅处理本地已收到的弹幕，不会额外请求平台接口，也不会消耗 Cookie。

## 下载与构建

仓库工作流支持以下应用构建：

- Android APK
- iOS IPA
- Windows 压缩包

可在 GitHub Actions 中手动运行对应的 App workflow。当前维护重点是 `simple_live_app`，TV 版本不在本分支的主要适配范围内。

### 本地环境

- Flutter SDK（需内置 Dart 3.10 或更高版本）
- Android SDK（构建 Android）
- Xcode（本机构建 iOS）
- Visual Studio 2022 C++ 工具链（构建 Windows 或运行带原生 hook 的测试）

### 获取依赖

```bash
cd simple_live_core
dart pub get

cd ../simple_live_app
flutter pub get
```

### 构建 Android

```bash
cd simple_live_app
flutter build apk --release
```

### 构建 Windows

```bash
cd simple_live_app
flutter build windows --release
```

### 构建 iOS

```bash
cd simple_live_app
flutter build ipa --release
```

iOS 本地构建必须在 macOS/Xcode 环境运行；Windows 用户可使用仓库的 iOS GitHub Actions workflow。

## 项目结构

| 目录 | 说明 |
| --- | --- |
| `simple_live_core` | 各平台接口、播放地址解析和弹幕协议 |
| `simple_live_app` | Flutter 主应用，覆盖 Android、iOS、Windows 等平台 |
| `simple_live_console` | 核心接口调试工具 |
| `simple_live_tv_app` | 上游 TV 应用代码，当前不作为主要维护目标 |
| `.github/workflows` | App 自动构建与发布工作流 |

## 开发验证

```bash
# Core 静态分析
cd simple_live_core
dart analyze

# 快手相关测试
dart test test/kuaishou_site_test.dart test/kuaishou_danmaku_test.dart

# App 静态分析
cd ../simple_live_app
flutter analyze
```

`dart_quickjs` 包含原生构建 hook；Windows 运行部分测试时需要可用的 MSVC C/C++ 编译器。

## 更新日志

参见 [CHANGELOG.md](CHANGELOG.md)。

## 上游与致谢

- [xiaoyaocz/dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live) — Simple Live 原始项目
- [June6699/dart_simple_live](https://github.com/June6699/dart_simple_live) — 本仓库采用的上游维护基础
- [heartsg/pure_live](https://github.com/heartsg/pure_live) — 快手站点适配参考
- [OrdinaryRoad-Project/ordinaryroad-barrage-fly](https://github.com/OrdinaryRoad-Project/ordinaryroad-barrage-fly) — 快手弹幕协议对照参考
- [wushuaihua520/BarrageGrab](https://github.com/wushuaihua520/BarrageGrab) — 多平台弹幕项目参考

## 许可

项目沿用仓库中的 [LICENSE](LICENSE)。使用、修改或分发前请同时遵守各直播平台的服务条款与当地法律法规。
