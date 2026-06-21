import 'package:simple_live_core/src/interface/live_danmaku.dart';

/// 快手弹幕 — 空实现（快手暂不支持弹幕）
class KuaishouDanmaku extends LiveDanmaku {
  @override
  int get heartbeatTime => 60000;

  @override
  Future start(dynamic args) async {
    onReady?.call();
  }

  @override
  Future stop() async {}

  @override
  void heartbeat() {}
}
