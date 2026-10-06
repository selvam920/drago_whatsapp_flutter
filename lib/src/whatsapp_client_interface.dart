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

  /// Adds [callback] for a WPP [event]. Several callbacks may share an event.
  Future<void> on(String event, Function(dynamic) callback);

  /// Removes [callback], or every callback this client added for [event]
  /// when it is null. Listeners added by other code are left alone.
  Future<void> off(String event, [Function(dynamic)? callback]);

  /// Re-attaches the JS side of every listener after a page reload.
  Future<void> restoreListeners();

  Future<void> reload();
  Future<void> loadUrl(String url);
  String? sessionPath;
}
