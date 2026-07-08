import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';

class KuaishouWebLoginController extends BaseController {
  static const _loginUrl = "https://live.kuaishou.com/";
  static const _reloadCooldown = Duration(seconds: 10);
  static const _rateLimitCooldown = Duration(minutes: 2);
  static const _userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0";

  WebUri get loginUri => WebUri(_loginUrl);
  String get userAgent => _userAgent;

  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  final progress = 0.0.obs;
  final checking = false.obs;
  final errorMessage = "".obs;
  DateTime? _lastNavigationAt;
  DateTime? _rateLimitedUntil;

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    _lastNavigationAt = DateTime.now();
  }

  void onProgressChanged(InAppWebViewController controller, int value) {
    progress.value = value / 100;
  }

  void onLoadStart(InAppWebViewController controller, Uri? uri) {
    progress.value = 0;
    errorMessage.value = "";
  }

  Future<void> onLoadStop(
    InAppWebViewController controller,
    Uri? uri,
  ) async {
    progress.value = 1;
    try {
      final bodyText = await controller.evaluateJavascript(
        source: "document.body ? document.body.innerText : ''",
      );
      final text = bodyText?.toString() ?? "";
      if (_isRateLimitedText(text)) {
        _rateLimitedUntil = DateTime.now().add(_rateLimitCooldown);
        errorMessage.value = "快手限制了当前登录请求，请等待约 2 分钟后再重试";
      } else {
        _rateLimitedUntil = null;
      }
    } catch (_) {}
  }

  void onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (request.isForMainFrame == true) {
      progress.value = 1;
      errorMessage.value = error.description;
    }
  }

  void onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (request.isForMainFrame == true) {
      progress.value = 1;
      errorMessage.value = "HTTP ${response.statusCode ?? "-"}";
    }
  }

  Future<void> reload() async {
    final now = DateTime.now();
    final rateLimitedUntil = _rateLimitedUntil;
    if (rateLimitedUntil != null && rateLimitedUntil.isAfter(now)) {
      final seconds = rateLimitedUntil.difference(now).inSeconds + 1;
      SmartDialog.showToast("请求过于频繁，请等待 $seconds 秒后重试");
      return;
    }
    final lastNavigationAt = _lastNavigationAt;
    if (lastNavigationAt != null &&
        now.difference(lastNavigationAt) < _reloadCooldown) {
      SmartDialog.showToast("页面刚刚加载，请勿连续刷新");
      return;
    }
    _lastNavigationAt = now;
    errorMessage.value = "";
    await webViewController?.reload();
  }

  Future<void> saveCookie({
    bool silent = false,
    bool autoClose = true,
  }) async {
    if (checking.value) {
      return;
    }
    checking.value = true;
    try {
      final snapshot = await _readCookie();
      var cookie = snapshot.cookie;
      final localStorageKww = await _readKww();
      if (localStorageKww.isNotEmpty &&
          _readCookieValue(cookie, 'kwfv1').isEmpty) {
        final encodedKww = Uri.encodeComponent(localStorageKww);
        cookie =
            cookie.isEmpty ? 'kwfv1=$encodedKww' : '$cookie; kwfv1=$encodedKww';
      }
      final kww = localStorageKww.isNotEmpty
          ? localStorageKww
          : _readCookieValue(cookie, 'kwfv1');
      if (cookie.isEmpty) {
        if (!silent) {
          SmartDialog.showToast("未读取到快手 Cookie");
        }
        return;
      }
      KuaishouAccountService.instance.setCookie(
        cookie,
        kww: kww,
        expiresAt: snapshot.expiresAt,
      );
      if (kww.isEmpty) {
        if (!silent || autoClose) {
          SmartDialog.showToast("Cookie 已保存，但未获取到 kwfv1；请刷新页面或完成验证后再保存");
        }
        return;
      }
      if (!silent || autoClose) {
        SmartDialog.showToast("快手 Cookie 已保存，可用于搜索和弹幕");
      }
      if (autoClose) {
        Get.back();
      }
    } catch (e) {
      Log.e("保存快手 Cookie 失败：$e", StackTrace.current);
      if (!silent) {
        SmartDialog.showToast("保存失败：$e");
      }
    } finally {
      checking.value = false;
    }
  }

  Future<_KuaishouCookieSnapshot> _readCookie() async {
    const expiryCookieNames = [
      "kuaishou.live.web_st",
      "kuaishou.server.web_st",
      "kuaishou.live.web_at",
      "passToken",
    ];
    final values = <String, String>{};
    int? latestExpiresDate;
    for (final url in const [
      "https://live.kuaishou.com",
      "https://kuaishou.com",
      "https://www.kuaishou.com",
    ]) {
      final cookies = await cookieManager.getCookies(url: WebUri(url));
      for (final item in cookies) {
        final name = item.name.trim();
        final value = item.value.trim();
        if (name.isNotEmpty && value.isNotEmpty) {
          values.putIfAbsent(name, () => value);
        }
        final expiresDate = item.expiresDate;
        if (expiryCookieNames.contains(name) &&
            expiresDate != null &&
            expiresDate > 0) {
          if (latestExpiresDate == null || expiresDate > latestExpiresDate) {
            latestExpiresDate = expiresDate;
          }
        }
      }
    }
    final expiresAt = latestExpiresDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(latestExpiresDate);
    return _KuaishouCookieSnapshot(
      cookie: values.entries.map((e) => "${e.key}=${e.value}").join("; "),
      expiresAt: expiresAt,
    );
  }

  Future<String> _readKww() async {
    final value = await webViewController?.evaluateJavascript(
      source: "window.localStorage.getItem('kwfv1') || ''",
    );
    return value?.toString().trim() ?? '';
  }

  bool _isRateLimitedText(String text) {
    return text.contains("请求频率太快") ||
        text.contains("操作过于频繁") ||
        text.contains("请求过于频繁") ||
        text.contains("璇锋眰棰戠巼澶揩") ||
        text.contains("鎿嶄綔杩囦簬棰戠箒");
  }

  String _readCookieValue(String cookie, String name) {
    for (final part in cookie.split(';')) {
      final item = part.trim();
      if (item.startsWith('$name=')) {
        return item.substring(name.length + 1).trim();
      }
    }
    return '';
  }
}

class _KuaishouCookieSnapshot {
  final String cookie;
  final DateTime? expiresAt;

  const _KuaishouCookieSnapshot({
    required this.cookie,
    required this.expiresAt,
  });
}
