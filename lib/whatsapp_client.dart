import 'dart:async';
import 'package:drago_whatsapp_flutter/src/inapp_webview_client_base.dart';
import 'package:drago_inappwebview/drago_inappwebview.dart';

/// Client over a [HeadlessInAppWebView] this package created and owns.
class WhatsappFlutterClient extends InAppWebViewClientBase {
  HeadlessInAppWebView? headlessInAppWebView;

  WhatsappFlutterClient({
    required super.controller,
    required this.headlessInAppWebView,
    super.sessionPath,
  });

  @override
  Future<void> dispose() async {
    await headlessInAppWebView?.dispose();
    controller = null;
    headlessInAppWebView = null;
  }

  @override
  bool isConnected() {
    return controller != null && (headlessInAppWebView?.isRunning() == true);
  }
}
