import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class InappViewPage extends StatefulWidget {
  final Function(InAppWebViewController) onReturn;
  const InappViewPage({super.key, required this.onReturn});

  @override
  State<InappViewPage> createState() => _InappViewPageState();
}

class _InappViewPageState extends State<InappViewPage> {
  InAppWebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InAppWebView(
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
          incognito: false,
          clearCache: false,
          cacheEnabled: true,
        ),
        onLoadStop: (controller, url) async {
          // check if whatsapp web redirected us to the wrong mobile version of whatsapp
          if (!url.toString().contains("web.whatsapp.com")) {
            //"Failed to load WhatsappWeb in Webview Mobile, please try again or clear cache of application"
          }
          webViewController = controller;
          widget.onReturn.call(controller);
        },
        onReceivedError: (controller, request, error) async {
          //error.toString()
        },
        onJsConfirm: (controller, jsConfirmRequest) async {
          print("JsConfirmRequest: ${jsConfirmRequest.message}");
          return JsConfirmResponse(action: JsConfirmResponseAction.CONFIRM);
        },
        onJsAlert: (controller, jsAlertRequest) async {
          print("JsAlertRequest: ${jsAlertRequest.message}");
          return JsAlertResponse(action: JsAlertResponseAction.CONFIRM);
        },
        onJsPrompt: (controller, jsPromptRequest) async {
          print("JsPromptRequest: ${jsPromptRequest.message}");
          return JsPromptResponse(action: JsPromptResponseAction.CONFIRM);
        },
      ),
    );
  }
}
