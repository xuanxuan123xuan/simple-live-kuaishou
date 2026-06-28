import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/danmaku/kuaishou_danmaku.dart';
import 'package:simple_live_core/src/interface/live_danmaku.dart';
import 'package:simple_live_core/src/interface/live_site.dart';
import 'package:simple_live_core/src/model/live_anchor_item.dart';
import 'package:simple_live_core/src/model/live_category.dart';
import 'package:simple_live_core/src/model/live_category_result.dart';
import 'package:simple_live_core/src/model/live_play_quality.dart';
import 'package:simple_live_core/src/model/live_play_url.dart';
import 'package:simple_live_core/src/model/live_room_detail.dart';
import 'package:simple_live_core/src/model/live_room_item.dart';
import 'package:simple_live_core/src/model/live_search_result.dart';

class KuaishouSite extends LiveSite {
  KuaishouSite() {
    id = "kuaishou";
    name = "快手直播";
  }

  /// 可选的自定义 Cookie
  String customCookie = '';

  String cookie = '';
  Map<String, String> cookieObj = {};

  static const List<String> _imageExtensions = [
    'svgz',
    'pjp',
    'png',
    'ico',
    'avif',
    'tiff',
    'tif',
    'jfif',
    'svg',
    'xbm',
    'pjpeg',
    'webp',
    'jpg',
    'jpeg',
    'bmp',
    'gif',
  ];

  Map<String, dynamic> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
    'connection': 'keep-alive',
    'sec-ch-ua': 'Google Chrome;v=120, Chromium;v=120, Not=A?Brand;v=24',
    'sec-ch-ua-platform': 'Windows',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-User': '?1',
  };

  Map<String, dynamic> _searchHeaders(String keyword) => {
    ..._headers,
    'accept': 'application/json, text/plain, */*',
    'referer':
        'https://live.kuaishou.com/search?keyword=${Uri.encodeComponent(keyword)}',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
  };

  @override
  LiveDanmaku getDanmaku() => KuaishouDanmaku();

  // ==================== 分类 ====================

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [
      LiveCategory(id: "1", name: "热门", children: []),
      LiveCategory(id: "2", name: "网游", children: []),
      LiveCategory(id: "3", name: "单机", children: []),
      LiveCategory(id: "4", name: "手游", children: []),
      LiveCategory(id: "5", name: "棋牌", children: []),
      LiveCategory(id: "6", name: "娱乐", children: []),
      LiveCategory(id: "7", name: "综合", children: []),
      LiveCategory(id: "8", name: "文化", children: []),
    ];

    for (var category in categories) {
      var subs = await _getAllSubCategories(category);
      category.children.addAll(subs);
    }
    return categories;
  }

  Future<List<LiveSubCategory>> _getAllSubCategories(
    LiveCategory category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    List<LiveSubCategory> allSubs = [];
    try {
      while (true) {
        var subs = await _getSubCategories(category, page, pageSize);
        allSubs.addAll(subs);
        if (subs.length < pageSize) break;
        page++;
      }
    } catch (_) {}
    return allSubs;
  }

  Future<List<LiveSubCategory>> _getSubCategories(
    LiveCategory category,
    int page,
    int pageSize,
  ) async {
    var result = await HttpClient.instance.getJson(
      "https://live.kuaishou.com/live_api/category/data",
      queryParameters: {"type": category.id, "page": page, "size": pageSize},
      header: _headers,
    );

    List<LiveSubCategory> subs = [];
    for (var item in result["data"]["list"] ?? []) {
      subs.add(
        LiveSubCategory(
          id: item["id"].toString(),
          name: item["name"] ?? "",
          parentId: category.id,
          pic: item["poster"],
        ),
      );
    }
    return subs;
  }

  // ==================== 分类直播间列表 ====================

  @override
  Future<LiveCategoryResult> getCategoryRooms(
    LiveSubCategory category, {
    int page = 1,
  }) async {
    var api = category.id.length < 7
        ? "https://live.kuaishou.com/live_api/gameboard/list"
        : "https://live.kuaishou.com/live_api/non-gameboard/list";

    var result = await HttpClient.instance.getJson(
      api,
      queryParameters: {
        "filterType": 0,
        "pageSize": 20,
        "gameId": category.id,
        "page": page,
      },
      header: _headers,
    );

    var items = <LiveRoomItem>[];
    for (var item in result["data"]["list"] ?? []) {
      var cover = item['poster']?.toString() ?? '';
      if (cover.isNotEmpty && !_isImage(cover)) {
        cover = '$cover.jpg';
      }
      items.add(
        LiveRoomItem(
          roomId: item["author"]["id"]?.toString() ?? '',
          title: item['caption']?.toString() ?? '',
          cover: cover,
          userName: item["author"]["name"]?.toString() ?? '',
          online: _parseInt(item["watchingCount"]),
        ),
      );
    }

    return LiveCategoryResult(hasMore: items.length >= 20, items: items);
  }

  // ==================== 推荐直播间 ====================

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://live.kuaishou.com/live_api/home/list",
      header: _headers,
    );

    var list = result['data']['list'] ?? [];
    var items = <LiveRoomItem>[];

    for (var item in list) {
      for (var sitem in item["gameLiveInfo"] ?? []) {
        for (var titem in sitem["liveInfo"] ?? []) {
          var author = titem["author"];
          var gameInfo = titem["gameInfo"];
          var cover = gameInfo['poster']?.toString() ?? '';
          items.add(
            LiveRoomItem(
              roomId: author["id"]?.toString() ?? '',
              title: author["name"]?.toString() ?? '',
              cover: cover,
              userName: author["name"]?.toString() ?? '',
              online: _parseInt(titem["watchingCount"]),
            ),
          );
        }
      }
    }

    return LiveCategoryResult(hasMore: false, items: items);
  }

  // ==================== 搜索 ====================

  @override
  Future<LiveSearchRoomResult> searchRooms(
    String keyword, {
    int page = 1,
  }) async {
    try {
      var result = await _searchLiveStreams(keyword, page: page);
      if (result.items.isNotEmpty || page > 1) {
        return result;
      }
    } catch (_) {}

    if (page > 1) {
      return LiveSearchRoomResult(hasMore: false, items: <LiveRoomItem>[]);
    }

    try {
      return await _searchRoomsByOverview(keyword);
    } catch (_) {
      return LiveSearchRoomResult(hasMore: false, items: <LiveRoomItem>[]);
    }
  }

  Future<LiveSearchRoomResult> _searchLiveStreams(
    String keyword, {
    int page = 1,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://live.kuaishou.com/live_api/search/liveStream",
      queryParameters: {"keyword": keyword, "page": page, "ussid": ""},
      header: _searchHeaders(keyword),
    );

    var data = result["data"];
    if (data is! Map || data["result"] != 1) {
      return LiveSearchRoomResult(hasMore: false, items: <LiveRoomItem>[]);
    }

    var list = (data["list"] as List?) ?? [];
    var items = <LiveRoomItem>[];
    for (var item in list) {
      var room = _parseSearchLiveRoom(item);
      if (room.roomId.isNotEmpty) {
        items.add(room);
      }
    }

    return LiveSearchRoomResult(hasMore: list.isNotEmpty, items: items);
  }

  Future<LiveSearchRoomResult> _searchRoomsByOverview(String keyword) async {
    var overview = await _getSearchOverview(keyword);
    var liveStreams = _findOverviewSectionList(overview, "liveStreams");
    var items = <LiveRoomItem>[];
    for (var item in liveStreams) {
      var room = _parseSearchLiveRoom(item);
      if (room.roomId.isNotEmpty) {
        items.add(room);
      }
    }
    if (items.isNotEmpty) {
      return LiveSearchRoomResult(hasMore: false, items: items);
    }

    var categories = _findOverviewSectionList(overview, "categories");
    if (categories.isEmpty) {
      return LiveSearchRoomResult(hasMore: false, items: <LiveRoomItem>[]);
    }

    var firstCategory = categories.first;
    var categoryId = firstCategory["categoryId"]?.toString() ?? '';
    if (categoryId.isEmpty) {
      return LiveSearchRoomResult(hasMore: false, items: <LiveRoomItem>[]);
    }

    var result = await getCategoryRooms(
      LiveSubCategory(
        id: categoryId,
        name: firstCategory["title"]?.toString() ?? keyword,
        parentId: firstCategory["category"]?.toString() ?? '',
        pic: firstCategory["src"]?.toString(),
      ),
    );
    return LiveSearchRoomResult(hasMore: result.hasMore, items: result.items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    try {
      var result = await _searchAnchors(keyword, page: page);
      if (result.items.isNotEmpty || page > 1) {
        return result;
      }
    } catch (_) {}

    if (page > 1) {
      return LiveSearchAnchorResult(hasMore: false, items: <LiveAnchorItem>[]);
    }

    try {
      var overview = await _getSearchOverview(keyword);
      var authors = _findOverviewSectionList(overview, "authors");
      var items = <LiveAnchorItem>[];
      for (var item in authors) {
        var anchor = _parseSearchAnchor(item);
        if (anchor.roomId.isNotEmpty) {
          items.add(anchor);
        }
      }
      return LiveSearchAnchorResult(hasMore: false, items: items);
    } catch (_) {
      return LiveSearchAnchorResult(hasMore: false, items: <LiveAnchorItem>[]);
    }
  }

  Future<LiveSearchAnchorResult> _searchAnchors(
    String keyword, {
    int page = 1,
  }) async {
    var result = await HttpClient.instance.getJson(
      "https://live.kuaishou.com/live_api/search/author",
      queryParameters: {
        "key": keyword,
        "keyword": keyword,
        "page": page,
        "count": 15,
        "ussid": "",
        "lssid": "",
      },
      header: _searchHeaders(keyword),
    );

    var data = result["data"];
    if (data is! Map || data["result"] != 1) {
      return LiveSearchAnchorResult(hasMore: false, items: <LiveAnchorItem>[]);
    }

    var list = (data["list"] as List?) ?? [];
    var items = <LiveAnchorItem>[];
    for (var item in list) {
      var anchor = _parseSearchAnchor(item);
      if (anchor.roomId.isNotEmpty) {
        items.add(anchor);
      }
    }

    return LiveSearchAnchorResult(hasMore: list.length >= 15, items: items);
  }

  Future<Map> _getSearchOverview(String keyword) async {
    var result = await HttpClient.instance.getJson(
      "https://live.kuaishou.com/live_api/search/overview",
      queryParameters: {"keyword": keyword, "ussid": ""},
      header: _searchHeaders(keyword),
    );
    var data = result["data"];
    return data is Map ? data : <String, dynamic>{};
  }

  List _findOverviewSectionList(Map overview, String type) {
    var sections = overview["list"];
    if (sections is! List) {
      return [];
    }
    for (var section in sections) {
      if (section is Map && section["type"] == type) {
        return (section["list"] as List?) ?? [];
      }
    }
    return [];
  }

  LiveRoomItem _parseSearchLiveRoom(dynamic item) {
    if (item is! Map) {
      return LiveRoomItem(roomId: '', title: '', cover: '', userName: '');
    }

    var author = item["author"] is Map ? item["author"] as Map : {};
    var gameInfo = item["gameInfo"] is Map ? item["gameInfo"] as Map : {};
    var cover =
        item["poster"]?.toString() ??
        item["coverUrl"]?.toString() ??
        gameInfo["poster"]?.toString() ??
        '';
    if (cover.isNotEmpty && !_isImage(cover)) {
      cover = '$cover.jpg';
    }

    return LiveRoomItem(
      roomId:
          author["id"]?.toString() ??
          item["authorId"]?.toString() ??
          item["userId"]?.toString() ??
          '',
      title:
          item["caption"]?.toString() ??
          item["title"]?.toString() ??
          author["name"]?.toString() ??
          '',
      cover: cover,
      userName:
          author["name"]?.toString() ?? item["userName"]?.toString() ?? '',
      online: _parseInt(item["watchingCount"]),
    );
  }

  LiveAnchorItem _parseSearchAnchor(dynamic item) {
    if (item is! Map) {
      return LiveAnchorItem(
        roomId: '',
        avatar: '',
        userName: '',
        liveStatus: false,
      );
    }

    return LiveAnchorItem(
      roomId: item["id"]?.toString() ?? '',
      avatar: item["avatar"]?.toString() ?? '',
      userName: item["name"]?.toString() ?? '',
      liveStatus: item["living"] == true,
    );
  }

  // ==================== 房间详情 ====================

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    var url = "https://live.kuaishou.com/u/$roomId";
    var mHeaders = _headers;

    if (customCookie.isNotEmpty) {
      mHeaders['cookie'] = customCookie;
    }

    // 获取 Cookie
    await _getCookie(url);
    // 注册 DID
    await _registerDid();

    var resultText = await HttpClient.instance.getText(
      url,
      queryParameters: {},
      header: mHeaders,
    );

    try {
      var text = RegExp(
        r"window\.__INITIAL_STATE__=(.*?);",
        multiLine: false,
      ).firstMatch(resultText)?.group(1);

      if (text == null) {
        return _offlineDetail(roomId);
      }

      var transferData = text.replaceAll("undefined", "null");
      var jsonObj = jsonDecode(transferData);

      var playList = jsonObj["liveroom"]["playList"];
      if (playList == null || playList.isEmpty) {
        return _offlineDetail(roomId);
      }

      var first = playList[0];
      var liveStream = first["liveStream"];
      var author = first["author"];
      var gameInfo = first["gameInfo"];
      var isLiving = first["isLiving"] ?? false;
      var liveStreamId = liveStream["id"]?.toString() ?? '';
      var websocketUrls = <String>[];
      var token = '';

      // 通过 websocketinfo API 获取最新的 token 和 websocketUrls
      if (liveStreamId.isNotEmpty) {
        try {
          var wsInfo = await _getWebSocketInfo(roomId, liveStreamId);
          token = wsInfo['token']?.toString() ?? '';
          var wsUrls = wsInfo['websocketUrls'];
          if (wsUrls is List) {
            for (var item in wsUrls) {
              var wsUrl = item?.toString() ?? '';
              if (wsUrl.isNotEmpty) {
                websocketUrls.add(wsUrl);
              }
            }
          }
        } catch (_) {
          // 如果 API 调用失败，回退到页面中的数据
          token = jsonObj["liveroom"]["token"]?.toString() ?? '';
          for (var item in jsonObj["liveroom"]["websocketUrls"] ?? []) {
            var wsUrl = item?.toString() ?? '';
            if (wsUrl.isNotEmpty) {
              websocketUrls.add(wsUrl);
            }
          }
        }
      }

      var cover = liveStream['poster']?.toString() ?? '';
      if (cover.isNotEmpty && !_isImage(cover)) {
        cover = '$cover.jpg';
      }

      return LiveRoomDetail(
        roomId: author["id"]?.toString() ?? roomId,
        title: author["name"]?.toString() ?? '',
        cover: cover,
        userName: author["name"]?.toString() ?? '',
        userAvatar: author["avatar"]?.toString() ?? '',
        online: isLiving ? _parseInt(gameInfo["watchingCount"]) : 0,
        introduction: author["description"]?.toString(),
        notice: author["description"]?.toString(),
        status: isLiving,
        url: liveStreamId,
        data: liveStream["playUrls"],
        danmakuData: KuaishouDanmakuArgs(
          roomId: author["id"]?.toString() ?? roomId,
          liveStreamId: liveStreamId,
          token: token,
          websocketUrls: websocketUrls,
          pageId: _generatePageId(),
          expTag: liveStream["expTag"]?.toString() ?? '',
          attach: first["expTag"]?.toString() ?? '',
          cookie: cookie,
        ),
        categoryId: gameInfo["id"]?.toString(),
        categoryName: gameInfo["name"]?.toString(),
      );
    } catch (_) {
      return _offlineDetail(roomId);
    }
  }

  Future<Map<String, dynamic>> _getWebSocketInfo(String roomId, String liveStreamId) async {
    var kww = cookieObj['kwfv1'] ?? '';
    var result = await HttpClient.instance.getJson(
      "https://live.kuaishou.com/live_api/liveroom/websocketinfo",
      queryParameters: {"caver": "2", "liveStreamId": liveStreamId},
      header: {
        ..._headers,
        "Referer": "https://live.kuaishou.com/u/$roomId",
        if (cookie.isNotEmpty) "Cookie": cookie,
        if (kww.isNotEmpty) "Kww": kww,
      },
    );

    var data = result['data'];
    if (data is! Map) {
      throw Exception("websocketinfo API 返回数据无效");
    }
    // 检查 API 调用是否成功（参考 Java 实现）
    var resultCode = data['result'];
    if (resultCode is int && resultCode != 1) {
      // 671 和 677 是未直播的状态码，其他错误码需要抛出异常
      if (resultCode != 671 && resultCode != 677) {
        throw Exception("websocketinfo API 调用失败: result=$resultCode");
      }
    }
    return data;
  }

  LiveRoomDetail _offlineDetail(String roomId) {
    return LiveRoomDetail(
      roomId: roomId,
      title: '',
      cover: '',
      userName: '',
      userAvatar: '',
      online: 0,
      status: false,
      url: '',
    );
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    try {
      final detail = await getRoomDetail(roomId: roomId);
      return detail.status;
    } catch (_) {
      return false;
    }
  }

  // ==================== 清晰度 ====================

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoomDetail detail,
  }) async {
    List<LivePlayQuality> qualities = [];

    try {
      var qualityList = detail.data["h264"]["adaptationSet"]["representation"];

      for (var quality in qualityList ?? []) {
        qualities.add(
          LivePlayQuality(
            quality: quality["name"]?.toString() ?? '',
            sort: quality["level"] ?? 0,
            data: <String>[quality["url"]?.toString() ?? ''],
          ),
        );
      }
    } catch (_) {}

    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) async {
    List<String> urls = [];
    if (quality.data is List) {
      for (var item in quality.data) {
        urls.add(item.toString());
      }
    }
    return LivePlayUrl(urls: urls);
  }

  // ==================== Cookie 管理 ====================

  Future<void> _getCookie(String url) async {
    final dio = Dio();
    final cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));
    await dio.get(url);
    List<Cookie> cookies = await cookieJar.loadForRequest(Uri.parse(url));
    cookie = '';
    cookieObj = <String, String>{};
    for (var i = 0; i < cookies.length; i++) {
      if (i != cookies.length - 1) {
        cookie += "${cookies[i].name}=${cookies[i].value};";
      } else {
        cookie += "${cookies[i].name}=${cookies[i].value}";
      }
      cookieObj[cookies[i].name] = cookies[i].value;
    }
  }

  // ==================== DID 注册 ====================

  Future<void> _registerDid() async {
    var did = cookieObj['did'];
    if (did == null || did.isEmpty) return;
    try {
      await HttpClient.instance.postJson(
        'https://log-sdk.ksapisrv.com/rest/wd/common/log/collect/misc2?v=3.9.49&kpn=KS_GAME_LIVE_PC',
        header: _headers,
        data: _buildMisc2Data(did),
      );
    } catch (_) {}
  }

  Map<String, dynamic> _buildMisc2Data(String did) {
    return {
      'common': {
        'identity_package': {'device_id': did, 'global_id': ''},
        'app_package': {
          'language': 'zh-CN',
          'platform': 10,
          'container': 'WEB',
          'product_name': 'KS_GAME_LIVE_PC',
        },
        'device_package': {
          'os_version': 'NT 10.0',
          'model': 'Windows',
          'ua':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        'need_encrypt': 'false',
        'network_package': {'type': 3},
        'h5_extra_attr':
            '{"sdk_name":"webLogger","sdk_version":"3.9.49","sdk_bundle":"log.common.js","app_version_name":"","host_product":"","resolution":"1920x1080","screen_with":1920,"screen_height":1080,"device_pixel_ratio":1,"domain":"https://live.kuaishou.com"}',
        'global_attr': '{}',
      },
      'logs': [
        {
          'client_timestamp': DateTime.now().millisecondsSinceEpoch,
          'client_increment_id': math.Random().nextInt(8999) + 1000,
          'session_id': _generateSessionId(),
          'time_zone': 'GMT+08:00',
          'event_package': {
            'task_event': {
              'type': 1,
              'status': 0,
              'operation_type': 1,
              'operation_direction': 0,
              'session_id': _generateSessionId(),
              'url_package': {
                'page': 'GAME_DETAL_PAGE',
                'identity': _generateUuid(),
                'page_type': 2,
                'params': '{"game_id":1001,"game_name":"王者荣耀"}',
              },
              'element_package': {},
            },
          },
        },
      ],
    };
  }

  String _generateSessionId() {
    return '${_hex(8)}-${_hex(4)}-${_hex(4)}-${_hex(4)}-${_hex(12)}';
  }

  String _generateUuid() {
    return '${_hex(8)}-${_hex(4)}-${_hex(4)}-${_hex(4)}-${_hex(12)}';
  }

  String _generatePageId() {
    const chars =
        'useandom-26T198340PX75pxJACKVERYMINDBUSHWOLF_GQZbfghjklqvwyzrict';
    final random = math.Random();
    final randomStr = List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
    return '$randomStr${DateTime.now().millisecondsSinceEpoch}';
  }

  String _hex(int length) {
    const chars = '0123456789abcdef';
    var result = '';
    for (var i = 0; i < length; i++) {
      result += chars[math.Random().nextInt(16)];
    }
    return result;
  }

  // ==================== 工具方法 ====================

  bool _isImage(String url) {
    if (url.isEmpty) return false;
    var ext = url.split('.').last.toLowerCase();
    return _imageExtensions.contains(ext);
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
}
