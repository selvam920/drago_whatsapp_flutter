library drago_whatsapp_flutter;

import 'dart:async';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:drago_whatsapp_flutter/whatsapp_client.dart';
import 'package:drago_whatsapp_flutter/whatsapp_inapp_client.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';

class DragoWhatsappFlutter {
  static Future<WhatsappClient?> connect({
    bool saveSession = false,
    int qrCodeWaitDurationSeconds = 60,
    Function(String qrCodeUrl, Uint8List? qrCodeImage)? onQrCode,
    Function(ConnectionEvent)? onConnectionEvent,
    Duration? connectionTimeout = const Duration(seconds: 20),
    Function(HeadlessInAppWebView? headlessInAppWebView)? onWebViewCreated,
  }) async {
    WpClientInterface? wpClient;

    try {
      onConnectionEvent?.call(ConnectionEvent.initializing);

      wpClient = await _getHeadLessInAppBrowser(saveSession);

      if (wpClient is WhatsappFlutterClient) {
        onWebViewCreated?.call(wpClient.headlessInAppWebView!);
      }

      await WppConnect.init(wpClient);

      onConnectionEvent?.call(ConnectionEvent.waitingForLogin);

      await waitForLogin(
        wpClient,
        onConnectionEvent: onConnectionEvent,
        onQrCode: onQrCode,
        waitDurationSeconds: qrCodeWaitDurationSeconds,
      );

      return WhatsappClient(wpClient: wpClient);
    } catch (e) {
      WhatsappLogger.log(e.toString());
      onWebViewCreated?.call(null);
      wpClient?.dispose();
      rethrow;
    }
  }

  static Future<WhatsappClient?> connectWithInAppBrowser({
    required InAppWebViewController controller,
    int qrCodeWaitDurationSeconds = 60,
    Function(String qrCodeUrl, Uint8List? qrCodeImage)? onQrCode,
    Function(ConnectionEvent)? onConnectionEvent,
    Duration? connectionTimeout = const Duration(seconds: 20),
  }) async {
    WpClientInterface? wpClient;

    try {
      wpClient = WhatsappInAppFlutterClient(controller: controller);
      await WppConnect.init(wpClient);
      await waitForLogin(
        wpClient,
        onConnectionEvent: onConnectionEvent,
        onQrCode: onQrCode,
        waitDurationSeconds: qrCodeWaitDurationSeconds,
      );

      return WhatsappClient(wpClient: wpClient);
    } catch (e) {
      WhatsappLogger.log(e.toString());
      wpClient?.dispose();
      rethrow;
    }
  }

  /// to run webView in headless mode and connect with it
  static Future<WhatsappFlutterClient> _getHeadLessInAppBrowser(
      bool keepSession) async {
    Completer<InAppWebViewController> completer = Completer();
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;

    HeadlessInAppWebView headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri.uri(
          Uri.parse(WhatsAppMetadata.whatsAppURL),
        ),
      ),
      onConsoleMessage: (controller, consoleMessage) {
        WhatsappLogger.log("ConsoleLog: ${consoleMessage.message}");
      },
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        return ServerTrustAuthResponse(
          action: ServerTrustAuthResponseAction.PROCEED,
        );
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        return NavigationActionPolicy.ALLOW;
      },
      initialSettings: InAppWebViewSettings(
        isInspectable: kDebugMode,
        preferredContentMode: UserPreferredContentMode.DESKTOP,
        userAgent: WhatsAppMetadata.userAgent,
        javaScriptEnabled: true,
        incognito: !keepSession,
        clearCache: !keepSession,
        cacheEnabled: keepSession,
      ),
      onLoadStop: (controller, url) async {
        // check if whatsapp web redirected us to the wrong mobile version of whatsapp
        if (!url.toString().contains("web.whatsapp.com")) {
          if (!completer.isCompleted) {
            completer.completeError(
              "Failed to load WhatsappWeb in Webview Mobile, please try again or clear cache of application",
            );
          }
        }
        if (!completer.isCompleted) {
          completer.complete(controller);
        }
      },
      onReceivedError: (controller, request, error) async {
        if (!completer.isCompleted) completer.completeError(error.toString());
      },
      onJsConfirm: (controller, jsConfirmRequest) async {
        //print("JsConfirmRequest: ${jsConfirmRequest.message}");
        return JsConfirmResponse(action: JsConfirmResponseAction.CONFIRM);
      },
      onJsAlert: (controller, jsAlertRequest) async {
        //print("JsAlertRequest: ${jsAlertRequest.message}");
        return JsAlertResponse(action: JsAlertResponseAction.CONFIRM);
      },
      onJsPrompt: (controller, jsPromptRequest) async {
        //print("JsPromptRequest: ${jsPromptRequest.message}");
        return JsPromptResponse(action: JsPromptResponseAction.CONFIRM);
      },
    );

    await headlessWebView.run();
    InAppWebViewController controller = await completer.future;

    return WhatsappFlutterClient(
      controller: controller,
      headlessInAppWebView: headlessWebView,
    );
  }
}
