import 'dart:async';
import 'package:drago_whatsapp_flutter/src/inapp_webview_client_base.dart';

/// Client over an [InAppWebView] the app embeds and owns; disposing only
/// drops the reference.
class WhatsappInAppFlutterClient extends InAppWebViewClientBase {
  WhatsappInAppFlutterClient({
    required super.controller,
    super.sessionPath,
  });

  @override
  Future<void> dispose() async {
    controller = null;
  }

  @override
  bool isConnected() {
    return controller != null;
  }
}
