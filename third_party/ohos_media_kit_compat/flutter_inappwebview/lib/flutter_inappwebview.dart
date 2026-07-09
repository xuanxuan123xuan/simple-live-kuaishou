import 'package:flutter/material.dart';

class InAppWebView extends StatelessWidget {
  final URLRequest? initialUrlRequest;
  final InAppWebViewSettings? initialSettings;
  final Function? onWebViewCreated;
  final Function? onLoadStart;
  final Function? onLoadStop;
  final Function? onProgressChanged;
  final Function? onReceivedError;
  final Function? onReceivedHttpError;
  final Function? onCreateWindow;
  final Function? shouldOverrideUrlLoading;

  const InAppWebView({
    super.key,
    this.initialUrlRequest,
    this.initialSettings,
    this.onWebViewCreated,
    this.onLoadStart,
    this.onLoadStop,
    this.onProgressChanged,
    this.onReceivedError,
    this.onReceivedHttpError,
    this.onCreateWindow,
    this.shouldOverrideUrlLoading,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('WebView is not available in the OHOS compatibility build.'),
    );
  }
}

class InAppWebViewController {
  Future<void> loadUrl({required URLRequest urlRequest}) async {}

  Future<void> reload() async {}

  Future<dynamic> evaluateJavascript({required String source}) async => null;
}

class InAppWebViewSettings {
  final String? userAgent;

  const InAppWebViewSettings({
    this.userAgent,
    UserPreferredContentMode? preferredContentMode,
    bool? useShouldOverrideUrlLoading,
    bool? javaScriptEnabled,
    bool? domStorageEnabled,
    bool? databaseEnabled,
    bool? sharedCookiesEnabled,
    bool? thirdPartyCookiesEnabled,
    bool? javaScriptCanOpenWindowsAutomatically,
    bool? supportMultipleWindows,
    bool? useOnLoadResource,
  });
}

class URLRequest {
  final WebUri? url;

  const URLRequest({this.url});
}

class WebUri {
  final Uri _uri;

  WebUri(String url) : _uri = Uri.parse(url);

  String get host => _uri.host;

  @override
  String toString() => _uri.toString();
}

class CreateWindowAction {
  final URLRequest request;

  const CreateWindowAction({required this.request});
}

class NavigationAction {
  final URLRequest request;

  const NavigationAction({required this.request});
}

enum NavigationActionPolicy {
  ALLOW,
  CANCEL,
}

enum UserPreferredContentMode {
  DESKTOP,
  MOBILE,
}

class WebResourceRequest {
  final bool? isForMainFrame;
  final WebUri? url;

  const WebResourceRequest({this.isForMainFrame, this.url});
}

class WebResourceError {
  final String description;

  const WebResourceError({this.description = ''});
}

class WebResourceResponse {
  final int? statusCode;

  const WebResourceResponse({this.statusCode});
}

class Cookie {
  final String name;
  final String value;
  final int? expiresDate;

  const Cookie({required this.name, required this.value, this.expiresDate});
}

class CookieManager {
  CookieManager._();

  static CookieManager instance() => CookieManager._();

  Future<List<Cookie>> getCookies({required WebUri url}) async => const [];

  Future<void> deleteAllCookies() async {}
}
