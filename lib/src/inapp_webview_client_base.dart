import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:drago_inappwebview/drago_inappwebview.dart';

/// Everything the headless and the embedded WebView clients do the same way.
///
/// Subclasses only decide how the WebView is owned: [dispose] and
/// [isConnected].
abstract class InAppWebViewClientBase implements WpClientInterface {
  InAppWebViewController? controller;

  @override
  String? sessionPath;

  InAppWebViewClientBase({required this.controller, this.sessionPath});

  /// Dart callbacks per WPP event. One JS bridge is installed per event, and
  /// it fans out to every callback here, so two listeners on the same event
  /// no longer replace each other.
  final Map<String, List<Function(dynamic)>> _listeners = {};

  OnNewEventFromListener? _customEventListener;

  @override
  Future injectJs(String content) async {
    await evaluateJs(content, tryPromise: false);
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
      final result =
          await controller?.callAsyncJavaScript(functionBody: functionBody);
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
        (async function()  {
          try {
            const canvas = document.querySelector('canvas');
            if (!canvas) return null;

            // Wait for canvas content if it's empty
            if (canvas.width <= 1 || canvas.height <= 1) {
               await new Promise(resolve => setTimeout(resolve, 1000));
            }

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
        tryPromise: true,
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

  static String _handlerName(String event) =>
      "callback_${event.replaceAll(".", "_")}";

  @override
  Future<void> on(String event, Function(dynamic) callback) async {
    final handlers = _listeners.putIfAbsent(event, () => []);
    handlers.add(callback);
    if (handlers.length > 1) return; // bridge already installed

    controller?.addJavaScriptHandler(
      handlerName: _handlerName(event),
      callback: (args) {
        final data = args.isNotEmpty ? args[0] : null;
        for (final handler in List.of(_listeners[event] ?? const [])) {
          handler(data);
        }
      },
    );
    await _attachJsListener(event);
  }

  Future<void> _attachJsListener(String event) async {
    final e = jsonEncode(event);
    final name = jsonEncode(_handlerName(event));
    await evaluateJs(
      '''(function() {
        window.__dragoListeners = window.__dragoListeners || {};
        if (window.__dragoListeners[$e]) return;
        var fn = function(data) { window.drago_inappwebview.callHandler($name, data); };
        window.__dragoListeners[$e] = fn;
        window.WPP.on($e, fn);
      })();''',
      tryPromise: false,
    );
  }

  /// Removes [callback] from [event], or every callback of this client when
  /// it is null. Only this client's own JS bridge is detached -- listeners
  /// that other code put on the same WPP event stay.
  @override
  Future<void> off(String event, [Function(dynamic)? callback]) async {
    final handlers = _listeners[event];
    if (handlers == null) return;
    if (callback != null) {
      handlers.remove(callback);
    } else {
      handlers.clear();
    }
    if (handlers.isNotEmpty) return;

    _listeners.remove(event);
    controller?.removeJavaScriptHandler(handlerName: _handlerName(event));
    final e = jsonEncode(event);
    await evaluateJs(
      '''(function() {
        var l = window.__dragoListeners;
        if (!l || !l[$e]) return;
        if (window.WPP) window.WPP.off($e, l[$e]);
        delete l[$e];
      })();''',
      tryPromise: false,
    );
  }

  @override
  Future initializeEventListener(
    OnNewEventFromListener onNewEventFromListener,
  ) async {
    _customEventListener = onNewEventFromListener;
    try {
      controller?.addJavaScriptHandler(
          handlerName: "onCustomEvent",
          callback: (arguments) {
            if (arguments.isEmpty || arguments[0] is! Map) return;
            final eventData = arguments[0] as Map;
            final type = eventData["type"];
            final data = eventData["data"];
            _customEventListener?.call(type.toString(), data);
          });
      await _attachCustomEvents();
    } catch (e) {
      WhatsappLogger.log("initializeEventListener_Error: $e");
    }
  }

  Future<void> _attachCustomEvents() async {
    await evaluateJs(
      '''
      (function() {
          window.onCustomEvent = (eventName, data) => window.drago_inappwebview.callHandler('onCustomEvent', {type: eventName, data: data});
          if (window.__dragoCustomEvents) return;
          window.__dragoCustomEvents = true;
          const events = [
            '${WhatsappEvent.connauthenticated}',
            '${WhatsappEvent.connlogout}',
            '${WhatsappEvent.connauthcodechange}',
            '${WhatsappEvent.connmainloaded}',
            '${WhatsappEvent.connmainready}',
            '${WhatsappEvent.connrequireauth}'
          ];
          events.forEach(event => {
            window.WPP.on(event, () => {
              window.onCustomEvent("connectionEvent", event);
            });
          });

          // Specific listener for QRCode Change
          window.WPP.on('${WhatsappEvent.connauthcodechange}', async () => {
            try {
              const canvas = document.querySelector('canvas');
              if (!canvas) return;
              const selectorUrl = canvas.closest('[data-ref]');
              const result = {
                'base64Image': canvas.toDataURL(),
                'urlCode': selectorUrl ? selectorUrl.getAttribute('data-ref') : null,
              };
              window.onCustomEvent("qrCodeEvent", result);
            } catch(e) {
               // ignore
            }
          });
      })()
      ''',
      tryPromise: false,
    );
  }

  /// A page reload drops every JS-side listener; the Dart handlers survive.
  /// Call after WPP is injected again to reconnect them.
  @override
  Future<void> restoreListeners() async {
    try {
      if (_customEventListener != null) await _attachCustomEvents();
      for (final event in _listeners.keys.toList()) {
        await _attachJsListener(event);
      }
    } catch (e) {
      WhatsappLogger.log("restoreListeners_Error: $e");
    }
  }

  @override
  Future<void> reload() async {
    await controller?.reload();
  }

  @override
  Future<void> loadUrl(String url) async {
    await controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }
}
