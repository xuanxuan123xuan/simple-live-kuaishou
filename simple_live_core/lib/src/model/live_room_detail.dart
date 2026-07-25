import 'dart:convert';

/// The confidence of a room's live state.
///
/// [unknown] is deliberately distinct from [offline]: providers frequently
/// return partial room payloads while a stream is still playable.
enum LiveStatusState { live, offline, unknown }

class LiveRoomDetail {
  /// 房间ID
  final String roomId;

  /// 房间标题
  final String title;

  /// 封面
  final String cover;

  /// 用户名
  final String userName;

  /// 头像
  final String userAvatar;

  /// 在线
  final int online;

  /// 介绍
  final String? introduction;

  /// 公告
  final String? notice;

  /// 状态
  final bool status;

  /// Provider-reported live state. When absent, retain the legacy boolean
  /// semantics so existing providers and callers stay compatible.
  final LiveStatusState? liveStatusState;

  /// 附加信息
  final dynamic data;

  /// 弹幕附加信息
  final dynamic danmakuData;

  /// 是否录播
  final bool isRecord;

  /// 链接
  final String url;

  /// 显示时间
  final String? showTime;

  /// 当前直播间所属分区 ID
  final String? categoryId;

  /// 当前直播间所属分区名称
  final String? categoryName;

  /// 当前直播间所属父分区 ID
  final String? categoryParentId;

  /// 当前直播间所属父分区名称
  final String? categoryParentName;

  /// 当前直播间所属分区图标
  final String? categoryPic;

  LiveRoomDetail({
    required this.roomId,
    required this.title,
    required this.cover,
    required this.userName,
    required this.userAvatar,
    required this.online,
    this.introduction,
    this.notice,
    required this.status,
    this.liveStatusState,
    this.data,
    this.danmakuData,
    required this.url,
    this.isRecord = false,
    this.showTime,
    this.categoryId,
    this.categoryName,
    this.categoryParentId,
    this.categoryParentName,
    this.categoryPic,
  });

  LiveStatusState get resolvedLiveStatus =>
      liveStatusState ??
      ((status || isRecord) ? LiveStatusState.live : LiveStatusState.offline);

  @override
  String toString() {
    return json.encode({
      "roomId": roomId,
      "title": title,
      "cover": cover,
      "userName": userName,
      "userAvatar": userAvatar,
      "online": online,
      "introduction": introduction,
      "notice": notice,
      "status": status,
      "liveStatusState": resolvedLiveStatus.name,
      "data": data.toString(),
      "danmakuData": danmakuData.toString(),
      "url": url,
      "isRecord": isRecord,
      "showTime": showTime,
      "categoryId": categoryId,
      "categoryName": categoryName,
      "categoryParentId": categoryParentId,
      "categoryParentName": categoryParentName,
      "categoryPic": categoryPic,
    });
  }
}
