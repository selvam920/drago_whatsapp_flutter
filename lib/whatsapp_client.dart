import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WhatsappFlutterClient implements WpClientInterface {
  InAppWebViewController? controller;
  HeadlessInAppWebView? headlessInAppWebView;

  @override
  String? sessionPath;

  WhatsappFlutterClient({
    required this.controller,
    required this.headlessInAppWebView,
    this.sessionPath,
  });

  @override
  Future injectJs(String content) async {
    await evaluateJs(content, tryPromise: false);
  }

  @override
  Future<void> dispose() async {
    await headlessInAppWebView?.dispose();
    controller = null;
    headlessInAppWebView = null;
  }

  @override
  Future evaluateJs(
    String source, {
    String? methodName,
    bool tryPromise = true,
    bool forceJsonParseResult = false,
  }) async {
    if (!tryPromise) {
      final result = await controller?.evaluateJavascript(source: source);
      if (methodName?.isNotEmpty == true) {
        WhatsappLogger.log("${methodName}_Result : $result");
      }
      return result;
    }

    final String functionBody = "return await $source;";

    try {
      final result = await controller?.callAsyncJavaScript(functionBody: functionBody);
      final value = result?.value;
      if (methodName?.isNotEmpty == true) {
        WhatsappLogger.log("${methodName}_Result : $value");
      }

      if (result?.error != null) {
        WhatsappLogger.log("${methodName}_Result_Error : ${result?.error}");
        throw result!.error!;
      }

      if (value == "true" || value == true) return true;
      if (value == "false" || value == false) return false;

      return value;
    } catch (e) {
      WhatsappLogger.log("${methodName}_Exception : $e");
      rethrow;
    }
  }

  @override
  Future<QrCodeImage?> getQrCode() async {
    try {
      if (Platform.isWindows) {
        final hasCanvas = await evaluateJs(
              "document.querySelector('canvas') != null",
              tryPromise: false,
            ) ==
            true;
        if (!hasCanvas) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }

      final result = await evaluateJs(
        '''
        (function()  {
          try {
            const canvas = document.querySelector('canvas');
            if (!canvas) return null;
            const selectorUrl = canvas.closest('[data-ref]');
            return {
              'base64Image': canvas.toDataURL(),
              'urlCode': selectorUrl ? selectorUrl.getAttribute('data-ref') : null,
            };
          } catch(e) {
            return null;
          }
        })()
        ''',
        tryPromise: false,
      );

      if (result == null || result is! Map) return null;

      return QrCodeImage(
        base64Image: result['base64Image'],
        urlCode: result['urlCode'],
      );
    } catch (e) {
      WhatsappLogger.log("QrCodeFetchingError: $e");
      return null;
    }
  }

  @override
  Future<Uint8List?> takeScreenshot() async {
    try {
      return await controller?.takeScreenshot();
    } catch (e) {
      WhatsappLogger.log("ScreenshotError: $e");
      return null;
    }
  }

  @override
  Future<void> on(String event, Function(dynamic) callback) async {
    final callbackName = "callback_${event.replaceAll(".", "_")}";
    await evaluateJs(
      "window.$callbackName = (data) => window.flutter_inappwebview.callHandler('$callbackName', data);",
      tryPromise: false,
    );
    controller?.addJavaScriptHandler(
      handlerName: callbackName,
      callback: (args) => callback(args.isNotEmpty ? args[0] : null),
    );
    await evaluateJs(
      "window.WPP.on('$event', (data) => window.$callbackName(data));",
      tryPromise: false,
    );
  }

  @override
  Future<void> off(String event) async {
    final callbackName = "callback_${event.replaceAll(".", "_")}";
    controller?.removeJavaScriptHandler(handlerName: callbackName);
    await evaluateJs(
      "window.WPP.removeAllListeners('$event');",
      tryPromise: false,
    );
  }

  @override
  Future initializeEventListener(
    OnNewEventFromListener onNewEventFromListener,
  ) async {
    try {
      await evaluateJs(
        "window.onCustomEvent = (eventName, data) => window.flutter_inappwebview.callHandler('onCustomEvent', {type: eventName, data: data});",
        tryPromise: false,
      );

      // Add Dart side method
      controller?.addJavaScriptHandler(
          handlerName: "onCustomEvent",
          callback: (arguments) {
            if (arguments.isEmpty || arguments[0] is! Map) return;
            final eventData = arguments[0] as Map;
            final type = eventData["type"];
            final data = eventData["data"];
            onNewEventFromListener.call(type.toString(), data);
          });

      // Add all listeners
      await evaluateJs(
        '''
        (function() {
            const events = [
              'conn.authenticated',
              'conn.logout',
              'conn.auth_code_change',
              'conn.main_loaded',
              'conn.main_ready',
              'conn.require_auth'
            ];
            events.forEach(event => {
              window.WPP.on(event, () => {
                window.onCustomEvent("connectionEvent", event.split('.').pop());
              });
            });
        })()
        ''',
        tryPromise: false,
      );
    } catch (e) {
      WhatsappLogger.log("initializeEventListener_Error: $e");
    }
  }

  @override
  Future<void> reload() async {
    await controller?.reload();
  }

  @override
  bool isConnected() {
    return controller != null && (headlessInAppWebView?.isRunning() == true);
  }
}
