## 未发布

- 鸿蒙 workflow 改为从华为 npm 源安装 hvigor，并在无 hvigorw 时回退使用全局 hvigor。

- 鸿蒙 workflow 改为从 flutter build --help 检测 hap 子命令，避免 --help 误判。

- 鸿蒙 workflow 构建 HAP 时动态检测 flutter build hap 参数，兼容无 --release 选项的 Flutter OHOS 分支。

- 鸿蒙构建将 file_picker 固定到 8.3.2，避开 win32 Dart 3.5 SDK 约束。

- 鸿蒙构建使用本地 wakelock_plus shim，避开 package_info_plus 9.x 依赖冲突。

- 鸿蒙构建将 archive 固定到 3.6.1，兼容 lottie 3.1.x 依赖约束。

- 鸿蒙构建将 lottie 固定到 3.1.3，兼容 Flutter OHOS Dart 3.4。

- 鸿蒙构建将 cross_file 固定到 0.3.4+2，兼容 Flutter OHOS Dart 3.4。

- 鸿蒙构建使用本地 flutter_inappwebview shim，避开上游插件 Dart 3.5 SDK 约束和原生平台依赖。

- 鸿蒙构建将 shelf 固定到 1.4.1，避开 Flutter OHOS 固定 collection 1.18.0 冲突。

- 降低 simple_live_core SDK 下限到 Dart 3.0.5，兼容 Flutter OHOS Dart 3.4 解析。

- 修复鸿蒙 pubspec.ohos.yaml 重复 dependency_overrides 导致的 pub get 解析失败。

- 鸿蒙构建使用本地 dart_quickjs shim，避开上游 git 包 Dart 3.10 SDK 约束。

- 鸿蒙构建将 extended_image 固定到 9.1.0，兼容 Flutter OHOS Dart 3.4。

- 鸿蒙构建将 device_info_plus 继续降到 11.3.0，避开 Flutter OHOS 固定 meta 1.12.0 冲突。

- 鸿蒙构建将 permission_handler 继续降到 11.3.1，兼容 Flutter OHOS Dart 3.4。

- 鸿蒙构建固定 package_info_plus、device_info_plus、share_plus、permission_handler、file_picker 到 Dart 3.4 兼容版本。

- 鸿蒙构建将 url_launcher 固定到 6.3.1，兼容 Flutter OHOS Dart 3.4。

- GitHub Actions 的 Flutter OHOS clone 增加重试和 HTTP/1.1 配置，降低 Gitee TLS 断流导致的 early EOF 失败概率。

- 鸿蒙构建使用本地 image_gallery_saver_plus shim，兼容 Flutter OHOS Dart 3.4 依赖解析。

- GitHub Actions 为 Flutter OHOS 3.22 分支补充本地标准 tag，修复 SDK 版本显示为 `0.0.0-unknown` 导致 `pub get` 失败的问题。
- `pubspec.ohos.yaml` 中 `intl` 按 Flutter OHOS 3.22 的 `flutter_localizations` 约束固定为 `0.19.0`，修复鸿蒙依赖解析冲突。
- Flutter OHOS 默认分支固定为 `3.22.1-ohos-0.1.0`，避免 GitHub Actions 拉到 Dart 2.x 旧分支导致依赖解析失败。
- README 重写为项目级说明，覆盖整体功能、平台支持、构建方式、鸿蒙 NEXT 适配和工作流说明。
# 更新日志

## 2026-06-28

### 新增

- 完整接入快手直播分类、推荐、直播间搜索、主播搜索、房间详情和多清晰度播放。
- 增加快手 protobuf WebSocket 弹幕，支持评论解析、颜色、gzip、心跳和备用线路重连。
- 增加 Android/iOS 快手 Web 登录入口，支持自动读取 Cookie 与 localStorage `kwfv1`。
- 增加快手 Cookie 手动粘贴、文件导入、查看和导出入口。
- 增加快手 Cookie 预计剩余有效期展示。
- 增加快手标题和直播状态解析测试。
- 增加 Android、iOS、Windows App 手动构建工作流。

### 修复

- 修复快手登录入口在账号页面不可见的问题。
- 修复手动 Cookie 配置错误要求 Kww 的问题；应用现在优先从 `kwfv1` 自动生成请求签名。
- 修复服务器刷新出的新 Cookie 被本地旧 Cookie 覆盖且未持久化，导致短期凭证快速失效或重启后回退旧值的问题。
- 修复 Cookie 有效期只读取短期 `web_st`、预计时间明显偏短的问题。
- 修复快手直播标题错误显示主播名的问题。
- 修复快手直播状态偶发误判为“未开播”的问题：Cookie 会话优先、匿名详情回退，并结合直播流和播放地址判断。
- 区分快手临时限流与 Cookie 真正失效，并调整误导性提示。
- 修复 Android 构建中 `libdart_quickjs.so` 重复打包的问题。
- 修复 Windows 最新 runner 工具链与部分 Flutter 插件不兼容的问题，固定使用 Windows Server 2022 runner。
- 修复 App workflow 默认分支仍指向旧 `master` 的问题，统一改为 `main`。

### 优化

- 快手网页登录兼容 Android Chrome 与 iOS Safari 桌面 User-Agent。
- WebView 登录启用 Cookie、DOM Storage 和跨页面 Cookie 采集。
- Web 登录改用原生 WebView 设备指纹和单次初始加载，并对连续刷新及平台限流页面增加冷却提示。
- 快手 Cookie 刷新限制为两分钟一次，DID 注册限制为每小时一次；短暂请求失败时可沿用三分钟内最近一次有效直播状态。
- 重点动态保持纯本地聚合，不额外请求平台接口。
- README 按当前功能、构建方式和维护范围重新整理。

### 验证

- 快手账号、Cookie、WebView 登录相关 Dart 静态分析通过。
- 快手核心实现及测试文件 Dart 静态分析通过。
- `git diff --check` 通过。
- Windows 本机缺少 MSVC C/C++ 编译器，因此 `dart_quickjs` 原生 hook 阻止了单元测试实际执行；CI 构建环境可继续验证完整测试链路。
