import 'dart:async';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/multi_room/multi_room_models.dart';
import 'package:simple_live_app/services/mpv_options_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class MultiRoomPlayerController extends GetxController {
  final MultiRoomItem item;

  MultiRoomPlayerController(this.item);

  late final Player player = Player(
    configuration: PlayerConfiguration(
      title: item.userName,
      logLevel: AppSettingsController.instance.logEnable.value
          ? MPVLogLevel.info
          : MPVLogLevel.error,
    ),
  );
  late final VideoController videoController = VideoController(
    player,
    configuration: MpvOptionsService.videoControllerConfiguration(),
  );

  final detail = Rx<LiveRoomDetail?>(null);
  final loading = true.obs;
  final liveStatus = false.obs;
  final errorText = "".obs;
  final muted = true.obs;
  final qualityInfo = "".obs;
  final lineInfo = "".obs;

  List<LivePlayQuality> _qualities = const [];
  List<String> _playUrls = const [];
  Map<String, String>? _playHeaders;
  int _qualityIndex = -1;
  int _lineIndex = 0;
  bool _disposed = false;

  String get title {
    final roomTitle = detail.value?.title.trim();
    if (roomTitle != null && roomTitle.isNotEmpty) {
      return roomTitle;
    }
    return item.userName;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(MpvOptionsService.applyToPlayer(player));
    unawaited(load());
  }

  Future<void> load() async {
    loading.value = true;
    errorText.value = "";
    liveStatus.value = false;
    try {
      await player.stop();
      final roomDetail =
          await item.site.liveSite.getRoomDetail(roomId: item.roomId);
      if (_disposed) {
        return;
      }
      detail.value = roomDetail;
      liveStatus.value = roomDetail.status || roomDetail.isRecord;
      if (!liveStatus.value) {
        return;
      }
      await _loadQualities(roomDetail);
      await _loadPlayUrls(roomDetail);
      await _openCurrentUrl();
    } catch (e) {
      Log.e(
        "多开直播间加载失败：${item.site.id}/${item.roomId} $e",
        StackTrace.current,
      );
      errorText.value = e.toString();
    } finally {
      if (!_disposed) {
        loading.value = false;
      }
    }
  }

  Future<void> _loadQualities(LiveRoomDetail roomDetail) async {
    _qualities = await item.site.liveSite.getPlayQualites(detail: roomDetail);
    if (_qualities.isEmpty) {
      throw Exception("无法读取播放清晰度");
    }
    final qualityLevel = AppSettingsController.instance.qualityLevel.value;
    if (qualityLevel == 2) {
      _qualityIndex = 0;
    } else if (qualityLevel == 0) {
      _qualityIndex = _qualities.length - 1;
    } else {
      _qualityIndex = (_qualities.length / 2).floor();
    }
    qualityInfo.value = _qualities[_qualityIndex].quality;
  }

  Future<void> _loadPlayUrls(LiveRoomDetail roomDetail) async {
    final playUrl = await item.site.liveSite.getPlayUrls(
      detail: roomDetail,
      quality: _qualities[_qualityIndex],
    );
    if (playUrl.urls.isEmpty) {
      throw Exception("无法读取播放地址");
    }
    _playUrls = playUrl.urls;
    _playHeaders = playUrl.headers;
    _lineIndex = 0;
    lineInfo.value = "线路${_lineIndex + 1}";
  }

  Future<void> _openCurrentUrl() async {
    var url = _playUrls[_lineIndex];
    if (AppSettingsController.instance.playerForceHttps.value) {
      url = url.replaceAll("http://", "https://");
    }
    await player.open(Media(url, httpHeaders: _playHeaders));
    await player.setVolume(
        muted.value ? 0 : AppSettingsController.instance.playerVolume.value);
  }

  Future<void> refreshRoom() async {
    await load();
    SmartDialog.showToast("已刷新 ${item.userName}");
  }

  Future<void> toggleMute() async {
    muted.value = !muted.value;
    await player.setVolume(
      muted.value ? 0 : AppSettingsController.instance.playerVolume.value,
    );
  }

  @override
  void onClose() {
    _disposed = true;
    unawaited(player.stop());
    unawaited(player.dispose());
    super.onClose();
  }
}
