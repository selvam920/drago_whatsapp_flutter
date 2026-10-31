import 'dart:async';
import 'package:drago_whatsapp_flutter/src/inapp_webview_client_base.dart';
import 'package:drago_inappwebview/drago_inappwebview.dart';

/// Client over a [HeadlessInAppWebView] this package created and owns.
class WhatsappFlutterClient extends InAppWebViewClientBase {
  HeadlessInAppWebView? headlessInAppWebView;

  /// The WebView2 environment the view runs in (Windows, kept session). It
  /// holds the Edge browser process tree, so it is closed with the view --
  /// left open, every reconnect left another browser running.
  WebViewEnvironment? environment;

  WhatsappFlutterClient({
    required super.controller,
    required this.headlessInAppWebView,
    this.environment,
    super.sessionPath,
  });

  @override
  Future<void> dispose() async {
    await headlessInAppWebView?.dispose();
    await environment?.dispose();
    controller = null;
    headlessInAppWebView = null;
    environment = null;
  }

  @override
  bool isConnected() {
    return controller != null && (headlessInAppWebView?.isRunning() == true);
  }
}
