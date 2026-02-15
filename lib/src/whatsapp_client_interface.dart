import 'dart:typed_data';

import 'package:drago_whatsapp_flutter/src/model/export_models.dart';

/// Interface for creating a Whatsapp Client

typedef OnNewEventFromListener = Function(String eventName, dynamic eventData);

abstract class WpClientInterface {
  Future injectJs(String content);

  Future<dynamic> evaluateJs(
    String source, {
    String? methodName,
    bool tryPromise,
    bool forceJsonParseResult,
  });

  Future<void> dispose();

  bool isConnected();

  Future initializeEventListener(OnNewEventFromListener onNewEventFromListener);

  Future<QrCodeImage?> getQrCode();

  Future<Uint8List?> takeScreenshot();

  Future<void> on(String event, Function(dynamic) callback);

  Future<void> off(String event);

  Future<void> reload();
  Future<void> loadUrl(String url);
  String? sessionPath;
}
