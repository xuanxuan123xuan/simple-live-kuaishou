import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/kuaishou_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class KuaishouWebLoginController extends BaseController {
  static const _loginUrl = "https://live.kuaishou.com/";
  static const _userAgent = KuaishouSite.userAgent;

  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  final progress = 0.0.obs;
  final checking = false.obs;

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    controller.loadUrl(urlRequest: URLRequest(url: WebUri(_loginUrl)));
  }

  void onProgressChanged(InAppWebViewController controller, int value) {
    progress.value = value / 100;
  }

  void onLoadStop(InAppWebViewController controller, Uri? uri) async {
    progress.value = 1;
    await saveCookie(silent: true, autoClose: false);
  }

  Future<void> reload() async {
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
      final cookie = await _readCookie();
      final localStorageKww = await _readKww();
      final kww = localStorageKww.isNotEmpty
          ? localStorageKww
          : _readCookieValue(cookie, 'kwfv1');
      if (cookie.isEmpty) {
        if (!silent) {
          SmartDialog.showToast("未读取到快手 Cookie");
        }
        return;
      }
      KuaishouAccountService.instance.setCookie(cookie, kww: kww);
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

  Future<String> _readCookie() async {
    final values = <String, String>{};
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
      }
    }
    return values.entries.map((e) => "${e.key}=${e.value}").join("; ");
  }

  Future<String> _readKww() async {
    final value = await webViewController?.evaluateJavascript(
      source: "window.localStorage.getItem('kwfv1') || ''",
    );
    return value?.toString().trim() ?? '';
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

  String get userAgent => _userAgent;
}
