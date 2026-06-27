import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/mine/account/kuaishou/web_login_controller.dart';

class KuaishouWebLoginPage extends GetView<KuaishouWebLoginController> {
  const KuaishouWebLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("快手网页登录"),
        actions: [
          IconButton(
            tooltip: "刷新",
            onPressed: controller.reload,
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: () => controller.saveCookie(),
            icon: const Icon(Icons.save_outlined),
            label: const Text("保存"),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Obx(
            () => LinearProgressIndicator(
              minHeight: 3,
              value: controller.progress.value >= 1
                  ? null
                  : controller.progress.value,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const ListTile(
              dense: true,
              leading: Icon(Icons.cookie_outlined),
              title: Text("登录快手网页后点右上角保存；保存后的 Cookie 会用于快手搜索和弹幕。"),
            ),
          ),
          Expanded(
            child: InAppWebView(
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStop: controller.onLoadStop,
              onProgressChanged: controller.onProgressChanged,
              initialSettings: InAppWebViewSettings(
                userAgent: controller.userAgent,
                useShouldOverrideUrlLoading: true,
                javaScriptCanOpenWindowsAutomatically: true,
                supportMultipleWindows: true,
              ),
              onCreateWindow: (webController, createWindowAction) async {
                final url = createWindowAction.request.url;
                if (url != null) {
                  await webController.loadUrl(urlRequest: URLRequest(url: url));
                }
                return false;
              },
            ),
          ),
        ],
      ),
    );
  }
}
