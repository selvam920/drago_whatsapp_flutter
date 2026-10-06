import 'dart:async';
import 'dart:io';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:drago_whatsapp_flutter/whatsapp_client.dart';
import 'package:drago_whatsapp_flutter/whatsapp_inapp_client.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';

class DragoWhatsappFlutter {
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

      onConnectionEvent?.call(ConnectionEvent.waitingForLogin);

      final loggedIn = await waitForLogin(
        wpClient,
        onConnectionEvent: onConnectionEvent,
        onQrCode: onQrCode,
        waitDurationSeconds: qrCodeWaitDurationSeconds,
        skipQrScan: skipQrScan,
        wppVersion: wppVersion,
        wppJsContent: wppJsContent,
        wppConfig: wppConfig,
        autoTakeover: autoTakeover,
      );

      if (!loggedIn) {
        WhatsappLogger.log('Not authenticated. skipQrScan=true, returning null.');
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

      final loggedIn = await waitForLogin(
        wpClient,
        onConnectionEvent: onConnectionEvent,
        onQrCode: onQrCode,
        waitDurationSeconds: qrCodeWaitDurationSeconds,
        skipQrScan: skipQrScan,
        wppVersion: wppVersion,
        wppJsContent: wppJsContent,
        wppConfig: wppConfig,
        autoTakeover: autoTakeover,
      );

      if (!loggedIn) {
        WhatsappLogger.log('Not authenticated. skipQrScan=true, returning null.');
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

      if (keepSession && !kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
     final availableVersion = await WebViewEnvironment.getAvailableVersion();
      assert(availableVersion != null,
           'Failed to find an installed WebView2 runtime or non-stable Microsoft Edge installation.');
      environment= await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
              userDataFolder: sessionPath));
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
      onJsConfirm: (controller, jsConfirmRequest) async =>
          JsConfirmResponse(action: JsConfirmResponseAction.CONFIRM),
      onJsAlert: (controller, jsAlertRequest) async =>
          JsAlertResponse(action: JsAlertResponseAction.CONFIRM),
      onJsPrompt: (controller, jsPromptRequest) async =>
          JsPromptResponse(action: JsPromptResponseAction.CONFIRM),
    );

    await headlessWebView.run();

    try {
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
      );
    } catch (e) {
      await headlessWebView.dispose();
      rethrow;
    }
  }

  /// [clearSession] will delete the session data and cookies
  static Future<void> clearSession({String? sessionPath}) async {
    try {
      if (sessionPath != null) {
        Directory directory = Directory(sessionPath);
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
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}
