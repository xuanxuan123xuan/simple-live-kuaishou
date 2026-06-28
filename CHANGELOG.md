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
- 修复服务器刷新出的新 Cookie 被本地旧 Cookie 覆盖，导致短期凭证快速失效的问题。
- 修复 Cookie 有效期只读取短期 `web_st`、预计时间明显偏短的问题。
- 修复快手直播标题错误显示主播名的问题。
- 修复快手直播状态偶发误判为“未开播”的问题：匿名详情优先、Cookie 详情回退，并结合直播流和播放地址判断。
- 修复 Android 构建中 `libdart_quickjs.so` 重复打包的问题。
- 修复 Windows 最新 runner 工具链与部分 Flutter 插件不兼容的问题，固定使用 Windows Server 2022 runner。
- 修复 App workflow 默认分支仍指向旧 `master` 的问题，统一改为 `main`。

### 优化

- 快手网页登录兼容 Android Chrome 与 iOS Safari 桌面 User-Agent。
- WebView 登录启用 Cookie、DOM Storage 和跨页面 Cookie 采集。
- 重点动态保持纯本地聚合，不额外请求平台接口。
- README 按当前功能、构建方式和维护范围重新整理。

### 验证

- 快手账号、Cookie、WebView 登录相关 Dart 静态分析通过。
- 快手核心实现及测试文件 Dart 静态分析通过。
- `git diff --check` 通过。
- Windows 本机缺少 MSVC C/C++ 编译器，因此 `dart_quickjs` 原生 hook 阻止了单元测试实际执行；CI 构建环境可继续验证完整测试链路。
