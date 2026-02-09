// Thanks to https://github.com/wppconnect-team/wa-js

import 'package:http/http.dart' as http;
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppConnect {
  /// make sure to call [init] to Initialize Wpp
  static Future init(
    WpClientInterface wpClient, {
    String? wppJsContent,
    String? wppVersion,
    Map<String, dynamic>? config,
  }) async {
    String wppUrl;
    if (wppVersion != null && wppVersion.isNotEmpty) {
      wppUrl =
          "https://github.com/wppconnect-team/wa-js/releases/download/$wppVersion/wppconnect-wa.js";
    } else {
      wppUrl =
          "https://github.com/wppconnect-team/wa-js/releases/latest/download/wppconnect-wa.js";
    }

    // Check if WPP is already present on the page (to avoid double injection)
    final isWppPresent = await wpClient.evaluateJs(
      '''typeof window.WPP !== 'undefined';''',
      tryPromise: false,
    );

    if (isWppPresent != true && isWppPresent?.toString() != "true") {
      WhatsappLogger.log("WPP not found, fetching and injecting script content...");
      try {
        String content = wppJsContent ??
            await http
                .read(Uri.parse(wppUrl))
                .timeout(const Duration(seconds: 30));
        
        // Inject the library as a string
        await wpClient.injectJs(content);
        WhatsappLogger.log("WPP script content injected, length: ${content.length}");
        
        // Give it a moment to parse and initialize
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        throw WhatsappException(
          exceptionType: WhatsappExceptionType.failedToConnect,
          message: "Failed to fetch or inject WPP script: $e",
        );
      }
    } else {
      WhatsappLogger.log("WPP already present on page, skipping injection");
    }

    // Wait for WPP to be fully initialized and Webpack modules to be ready
    if (!await _waitForWppReady(wpClient, 60)) {
      throw const WhatsappException(
        exceptionType: WhatsappExceptionType.failedToConnect,
        message: "Timed out waiting for WPP to be ready",
      );
    }

    // Modern WA-JS configuration
    await _configureWpp(wpClient, config: config);

    WhatsappLogger.log("WPP initialized and configured");
  }

  static Future<void> _configureWpp(WpClientInterface wpClient,
      {Map<String, dynamic>? config}) async {
    // Enable automatic chat creation when sending messages to new numbers
    await wpClient.evaluateJs(
      "window.WPP.chat.defaultSendMessageOptions.createChat = true;",
      tryPromise: false,
    );
    // Ensure connection stays alive
    await wpClient.evaluateJs(
      "window.WPP.conn.setKeepAlive(true);",
      tryPromise: false,
    );
    // Set custom bot identifier
    await wpClient.evaluateJs(
      "window.WPP.config.poweredBy = 'Whatsapp-Bot-Flutter';",
      tryPromise: false,
    );

    // Bypassing some heavy modules to speed up loading (Fast Connect logic)
    await wpClient.evaluateJs(
      '''
      if (typeof window.WPP !== 'undefined') {
        // Handle session takeover automatically
        window.WPP.on('conn.takeover', () => {
          console.log('Takeover detected, taking back control...');
          window.WPP.conn.takeover();
        });
      }
      ''',
      tryPromise: false,
    );

    // Apply custom configs
    if (config != null) {
      for (var entry in config.entries) {
        final key = entry.key;
        final value = entry.value;
        final jsValue = value is String ? "'$value'" : value;
        await wpClient.evaluateJs(
          "window.WPP.config.$key = $jsValue;",
          tryPromise: false,
        );
      }
    }
  }

  static Future<bool> _waitForWppReady(
    WpClientInterface wpClient,
    int tryCount,
  ) async {
    int count = 0;
    while (count < tryCount) {
      try {
        var result = await wpClient.evaluateJs(
          '''
          (function() {
            try {
              return {
                present: typeof window.WPP !== 'undefined',
                isReady: typeof window.WPP !== 'undefined' && !!window.WPP.isReady,
                webpackReady: typeof window.WPP !== 'undefined' && !!window.WPP.webpack && !!window.WPP.webpack.isReady,
                // On some versions, isReady might be enough
              };
            } catch(e) {
              return { error: e.toString() };
            }
          })()
          ''',
          tryPromise: false,
        );
        
        if (result is Map) {
          bool present = result['present'] == true;
          bool isReady = result['isReady'] == true;
          bool webpackReady = result['webpackReady'] == true;

          // Goal: Both must be true, but if isReady is true and webpack is missing,
          // it might be a version that changed internals. 
          // However, standard wa-js uses webpack.isReady.
          if (present && (isReady || webpackReady)) {
             // Second check: wait a bit more if webpackReady is false but isReady is true
             if (isReady && !webpackReady && count < 5) {
                // wait a bit more
             } else {
                return true;
             }
          }
          
          if (count % 5 == 0) {
            WhatsappLogger.log("WPP Status: count=$count, present=$present, isReady=$isReady, webpackReady=$webpackReady");
          }
        } else {
          if (count % 5 == 0) {
             WhatsappLogger.log("WPP Status: result is not a map: $result");
          }
        }
      } catch (e) {
        // Ignore evaluation errors during boot
      }
      
      await Future.delayed(const Duration(seconds: 1));
      count++;
    }
    return false;
  }
}
