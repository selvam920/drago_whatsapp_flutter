import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drago_whatsapp_flutter/src/helper/qr_code_helper.dart';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:drago_whatsapp_flutter/whatsapp_client.dart';
import 'package:drago_whatsapp_flutter/whatsapp_inapp_client.dart';
import 'package:drago_inappwebview/drago_inappwebview.dart';
import 'package:flutter/foundation.dart';

class DragoWhatsappFlutter {
  /// Android: sends WhatsApp Web's connections through [proxy] --
  /// `user:password@host:port` or `host:port` -- or straight out when null.
  ///
  /// For an app whose process is bound to a Wi-Fi without internet (to reach
  /// a LAN server) while mobile data has it: the app's own loopback proxy
  /// over mobile data takes WhatsApp Web out. Applies to every WebView in
  /// the app (Android's proxy override is process wide) and to a WhatsApp
  /// Web already open (its next connections). The user/password answer the
  /// proxy's 407. A no-op off Android, or where the WebView cannot take a
  /// proxy override (older System WebView).
  static Future<void> setProxy(String? proxy) {
    final next = _proxyOp.then((_) => _applyProxy(_WebViewProxy.parse(proxy)));
    _proxyOp = next.catchError((Object _) {});
    return next;
  }

  static Future<void> _proxyOp = Future.value();
  static _WebViewProxy? _proxy;

  static Future<void> _applyProxy(_WebViewProxy? next) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (next?.key == _proxy?.key) return;
    try {
      final controller = ProxyController.instance();
      if (next == null) {
        await controller.clearProxyOverride();
      } else {
        await controller.setProxyOverride(
          settings: ProxySettings(
            proxyRules: [ProxyRule(url: '${next.host}:${next.port}')],
            bypassRules: const ['<local>'],
          ),
        );
      }
      _proxy = next;
    } catch (e) {
      WhatsappLogger.log('setProxy failed: $e');
    }
  }

  /// The proxy's own 407 (see [setProxy]); any other sign-in request is
  /// turned down, as before.
  static Future<HttpAuthResponse?> _answerAuth(
    InAppWebViewController controller,
    HttpAuthenticationChallenge challenge,
  ) async {
    final proxy = _proxy;
    if (proxy != null &&
        proxy.username != null &&
        challenge.protectionSpace.host == proxy.host &&
        challenge.previousFailureCount <= 3) {
      return HttpAuthResponse(
        username: proxy.username!,
        password: proxy.password ?? '',
        action: HttpAuthResponseAction.PROCEED,
      );
    }
    return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
  }

  /// [connect] will initialize the connection to Whatsapp Web
  /// it will return [WhatsappClient] if connection is successful
  static Future<WhatsappClient?> connect({
    bool saveSession = false,
    String? sessionPath,
    int qrCodeWaitDurationSeconds = 60,
    Function(String qrCodeUrl, Uint8List? qrCodeImage)? onQrCode,
    Function(ConnectionEvent)? onConnectionEvent,
    Duration? connectionTimeout = const Duration(seconds: 20),
    Function(HeadlessInAppWebView? headlessInAppWebView)? onWebViewCreated,
    String? wppVersion,
    String? wppJsContent,
    Map<String, dynamic>? wppConfig,
    @Deprecated('Turns off TLS certificate checks for every HttpClient in '
        'the app. WhatsApp Web does not need it; will be removed.')
    bool enableHttpOverrides = false,
    bool skipQrScan = false,
    bool autoTakeover = true,
  }) async {
    WpClientInterface? wpClient;

    try {
      if (enableHttpOverrides) {
        // ignore: deprecated_member_use_from_same_package
        HttpOverrides.global = MyHttpOverrides();
      }
      onConnectionEvent?.call(ConnectionEvent.initializing);

      wpClient = await _getHeadLessInAppBrowser(
        saveSession,
        sessionPath: sessionPath,
        wppVersion: wppVersion,
      );
      wpClient.sessionPath = sessionPath;

      if (wpClient is WhatsappFlutterClient) {
        onWebViewCreated?.call(wpClient.headlessInAppWebView);
      }

      final loggedIn = await _initAndLogin(
        wpClient,
        onConnectionEvent: onConnectionEvent,
        onQrCode: onQrCode,
        qrCodeWaitDurationSeconds: qrCodeWaitDurationSeconds,
        skipQrScan: skipQrScan,
        wppVersion: wppVersion,
        wppJsContent: wppJsContent,
        wppConfig: wppConfig,
        autoTakeover: autoTakeover,
      );
      final wppEvents = loggedIn.events;

      if (!loggedIn.ok) {
        WhatsappLogger.log(
            'Not authenticated. skipQrScan=true, returning null.');
        await wpClient.dispose();
        onWebViewCreated?.call(null);
        return null;
      }

      return WhatsappClient(
        wpClient: wpClient,
        wppEvents: wppEvents,
      );
    } catch (e) {
      WhatsappLogger.log("Connect Error: $e");
      onWebViewCreated?.call(null);
      await wpClient?.dispose();
      rethrow;
    }
  }

  static Future<WhatsappClient?> connectWithInAppBrowser({
    required InAppWebViewController controller,
    int qrCodeWaitDurationSeconds = 60,
    Function(String qrCodeUrl, Uint8List? qrCodeImage)? onQrCode,
    Function(ConnectionEvent)? onConnectionEvent,
    Duration? connectionTimeout = const Duration(seconds: 20),
    String? wppVersion,
    String? wppJsContent,
    Map<String, dynamic>? wppConfig,
    @Deprecated('Turns off TLS certificate checks for every HttpClient in '
        'the app. WhatsApp Web does not need it; will be removed.')
    bool enableHttpOverrides = false,
    bool skipQrScan = false,
    bool autoTakeover = true,
  }) async {
    WpClientInterface? wpClient;

    try {
      if (enableHttpOverrides) {
        // ignore: deprecated_member_use_from_same_package
        HttpOverrides.global = MyHttpOverrides();
      }

      wpClient = WhatsappInAppFlutterClient(controller: controller);
      wpClient.sessionPath =
          null; // InAppBrowser might not expose session path easily or it's handled by controller
      final loggedIn = await _initAndLogin(
        wpClient,
        onConnectionEvent: onConnectionEvent,
        onQrCode: onQrCode,
        qrCodeWaitDurationSeconds: qrCodeWaitDurationSeconds,
        skipQrScan: skipQrScan,
        wppVersion: wppVersion,
        wppJsContent: wppJsContent,
        wppConfig: wppConfig,
        autoTakeover: autoTakeover,
        reportWaiting: false,
      );
      final wppEvents = loggedIn.events;

      if (!loggedIn.ok) {
        WhatsappLogger.log(
            'Not authenticated. skipQrScan=true, returning null.');
        await wpClient.dispose();
        return null;
      }

      return WhatsappClient(
        wpClient: wpClient,
        wppEvents: wppEvents,
      );
    } catch (e) {
      WhatsappLogger.log(e.toString());
      await wpClient?.dispose();
      rethrow;
    }
  }

  /// Injects wa-js, attaches the events and waits for the login. While wa-js
  /// loads (seconds on a slow PC), the QR WhatsApp Web already drew is shown
  /// straight from the page by an [EarlyQrWatcher] -- never for a quiet
  /// [skipQrScan] start, which must not show a QR.
  static Future<({bool ok, WppEvents events})> _initAndLogin(
    WpClientInterface wpClient, {
    required Function(ConnectionEvent)? onConnectionEvent,
    required Function(String qrCodeUrl, Uint8List? qrCodeImage)? onQrCode,
    required int qrCodeWaitDurationSeconds,
    required bool skipQrScan,
    required String? wppVersion,
    required String? wppJsContent,
    required Map<String, dynamic>? wppConfig,
    required bool autoTakeover,
    bool reportWaiting = true,
  }) async {
    EarlyQrWatcher? early;
    if (!skipQrScan && onQrCode != null) {
      var told = false;
      early = EarlyQrWatcher(wpClient, (qr) {
        Uint8List? bytes;
        try {
          bytes = base64Decode(qr.base64Image!
              .replaceFirst(RegExp(r'data:image\/[a-zA-Z]+;base64,'), ''));
        } catch (e) {
          WhatsappLogger.log('Error decoding QR image: $e');
          return;
        }
        // The apps show a QR while the last event is waitingForQrScan.
        if (!told) {
          told = true;
          onConnectionEvent?.call(ConnectionEvent.waitingForQrScan);
        }
        onQrCode(qr.urlCode!, bytes);
      })
        ..start();
    }
    try {
      await WppConnect.init(
        wpClient,
        wppVersion: wppVersion,
        wppJsContent: wppJsContent,
        config: wppConfig,
        autoTakeover: autoTakeover,
      );

      // Initialize Events before waiting for login to capture early events
      final wppEvents = WppEvents(wpClient);
      await wppEvents.init();
      early?.stop();
      final shown = early?.lastCode;

      // A QR already up stays up: "waiting for login" would hide it.
      if (reportWaiting && shown == null) {
        onConnectionEvent?.call(ConnectionEvent.waitingForLogin);
      }

      final ok = await waitForLogin(
        wpClient,
        onConnectionEvent: onConnectionEvent,
        onQrCode: onQrCode,
        waitDurationSeconds: qrCodeWaitDurationSeconds,
        skipQrScan: skipQrScan,
        wppVersion: wppVersion,
        wppJsContent: wppJsContent,
        wppConfig: wppConfig,
        autoTakeover: autoTakeover,
        shownQrCode: shown,
      );
      return (ok: ok, events: wppEvents);
    } finally {
      early?.stop();
    }
  }

  /// to run webView in headless mode and connect with it
  static Future<WhatsappFlutterClient> _getHeadLessInAppBrowser(
    bool keepSession, {
    String? sessionPath,
    String? wppVersion,
  }) async {
    final completer = Completer<InAppWebViewController>();
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;

    if (!keepSession && !Platform.isWindows) {
      await InAppWebViewController.clearAllCache();
    }

    WebViewEnvironment? environment;

    if (keepSession &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows) {
      final availableVersion = await WebViewEnvironment.getAvailableVersion();
      assert(availableVersion != null,
          'Failed to find an installed WebView2 runtime or non-stable Microsoft Edge installation.');
      // WebView2 can fail transiently (e.g. "device is not ready" right after
      // wake or while the runtime updates), so retry a few times.
      for (var attempt = 1;; attempt++) {
        try {
          environment = await WebViewEnvironment.create(
              settings:
                  WebViewEnvironmentSettings(userDataFolder: sessionPath));
          break;
        } catch (e) {
          if (attempt >= 3) rethrow;
          WhatsappLogger.log('WebViewEnvironment.create failed ($attempt): $e');
          await Future.delayed(Duration(milliseconds: 700 * attempt));
        }
      }
    }

    final headlessWebView = HeadlessInAppWebView(
      webViewEnvironment: environment,
      initialUrlRequest: URLRequest(
        url: WebUri.uri(Uri.parse(WhatsAppMetadata.whatsAppURL)),
      ),
      onConsoleMessage: (controller, consoleMessage) {
        WhatsappLogger.log("ConsoleLog: ${consoleMessage.message}");
      },
      initialSettings: InAppWebViewSettings(
        isInspectable: kDebugMode,
        preferredContentMode: UserPreferredContentMode.DESKTOP,
        userAgent: WhatsAppMetadata.userAgent,
        javaScriptEnabled: true,
        appCachePath: sessionPath,
        incognito: !keepSession,
        cacheEnabled: keepSession,
      ),
      onLoadStop: (controller, url) async {
        final urlString = url.toString();
        if (!urlString.contains("web.whatsapp.com")) {
          if (!completer.isCompleted) {
            completer.completeError(
              const WhatsappException(
                message: "Failed to load WhatsappWeb: unexpected redirect",
                exceptionType: WhatsappExceptionType.failedToConnect,
                details: "Redirected to non-whatsapp URL",
              ),
            );
          }
          return;
        }
        if (!completer.isCompleted) {
          completer.complete(controller);
        }
      },
      onReceivedError: (controller, request, error) async {
        if (!completer.isCompleted) {
          completer.completeError(
            WhatsappException(
              message: "WebView Error: ${error.description}",
              exceptionType: WhatsappExceptionType.failedToConnect,
              details: error.toString(),
            ),
          );
        }
      },
      onReceivedHttpAuthRequest: _answerAuth,
      onJsConfirm: (controller, jsConfirmRequest) async =>
          JsConfirmResponse(action: JsConfirmResponseAction.CONFIRM),
      onJsAlert: (controller, jsAlertRequest) async =>
          JsAlertResponse(action: JsAlertResponseAction.CONFIRM),
      onJsPrompt: (controller, jsPromptRequest) async =>
          JsPromptResponse(action: JsPromptResponseAction.CONFIRM),
    );

    try {
      await headlessWebView.run();
      final controller = await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw const WhatsappException(
          message: "WebView initialization timed out",
          exceptionType: WhatsappExceptionType.failedToConnect,
        ),
      );

      return WhatsappFlutterClient(
        controller: controller,
        headlessInAppWebView: headlessWebView,
        environment: environment,
      );
    } catch (e) {
      await headlessWebView.dispose();
      // The environment holds the browser process; a failed start must not
      // leave it running.
      await environment?.dispose();
      rethrow;
    }
  }

  /// [clearSession] will delete the session data and cookies
  static Future<void> clearSession({String? sessionPath}) async {
    try {
      if (sessionPath != null) {
        // On Windows only the WebView2 profile inside sessionPath is removed:
        // callers have passed folders that also hold their own data.
        Directory directory = Platform.isWindows
            ? Directory('$sessionPath${Platform.pathSeparator}EBWebView')
            : Directory(sessionPath);
        try {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        } catch (e) {
          WhatsappLogger.log(e);
        }
      }
      await CookieManager.instance().deleteAllCookies();
      if (!Platform.isWindows) {
        await InAppWebViewController.clearAllCache();
      }
    } catch (e) {
      WhatsappLogger.log(e);
    }
  }
}

/// Accepts any TLS certificate for every host -- do not install globally.
@Deprecated('Disables TLS certificate validation app-wide; will be removed.')

/// A [DragoWhatsappFlutter.setProxy] address.
class _WebViewProxy {
  final String host;
  final int port;
  final String? username;
  final String? password;
  const _WebViewProxy(this.host, this.port, this.username, this.password);

  String get key => '$username:$password@$host:$port';

  /// `user:password@host:port` / `host:port`; null for null or anything
  /// else.
  static _WebViewProxy? parse(String? proxy) {
    if (proxy == null || proxy.trim().isEmpty) return null;
    var rest = proxy.trim();
    String? user, pass;
    final at = rest.lastIndexOf('@');
    if (at >= 0) {
      final cred = rest.substring(0, at);
      rest = rest.substring(at + 1);
      final colon = cred.indexOf(':');
      user = colon < 0 ? cred : cred.substring(0, colon);
      pass = colon < 0 ? null : cred.substring(colon + 1);
    }
    final colon = rest.lastIndexOf(':');
    if (colon <= 0) return null;
    final port = int.tryParse(rest.substring(colon + 1));
    if (port == null || port <= 0 || port > 65535) return null;
    return _WebViewProxy(rest.substring(0, colon), port, user, pass);
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}
