// Thanks to https://github.com/wppconnect-team/wa-js

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppConnect {
  /// The wa-js release used when the app names none. Pinned so an upstream
  /// release can't change every installation overnight; bump it after testing
  /// a new release. When this download fails the latest release is tried.
  static const String defaultWppVersion = 'v4.6.1';

  static final Map<String, String> _cachedWppJs = {};

  static String _releaseUrl(String version) => version == 'latest'
      ? "https://github.com/wppconnect-team/wa-js/releases/latest/download/wppconnect-wa.js"
      : "https://github.com/wppconnect-team/wa-js/releases/download/$version/wppconnect-wa.js";

  static Future<String> _fetchWppJs(String version) async {
    final cached = _cachedWppJs[version];
    if (cached != null) return cached;
    final content = await http
        .read(Uri.parse(_releaseUrl(version)))
        .timeout(const Duration(seconds: 30));
    _cachedWppJs[version] = content;
    return content;
  }

  /// make sure to call [init] to Initialize Wpp
  ///
  /// [wppJsContent] injects a copy the app ships instead of downloading one.
  /// [autoTakeover] takes the session back whenever WhatsApp Web is opened
  /// somewhere else; turn it off when the business also uses WhatsApp Web in
  /// a browser, or the two keep kicking each other off.
  static Future init(
    WpClientInterface wpClient, {
    String? wppJsContent,
    String? wppVersion,
    Map<String, dynamic>? config,
    bool autoTakeover = true,
  }) async {
    final version = (wppVersion != null && wppVersion.isNotEmpty)
        ? wppVersion
        : defaultWppVersion;

    // Check if WPP is already present on the page (to avoid double injection)
    // We only check for presence, not 'isReady' here, to skip injection correctly
    final isWppPresent = await wpClient.evaluateJs(
      '''typeof window.WPP !== 'undefined';''',
      tryPromise: false,
    );

    if (isWppPresent != true && isWppPresent?.toString() != "true") {
      // Check if we are on the correct page before injection
      final currentUrl = await wpClient.evaluateJs("window.location.href", tryPromise: false);
      if (currentUrl != null && !currentUrl.toString().contains("web.whatsapp.com")) {
        WhatsappLogger.log("Not on WhatsApp Web page ($currentUrl), loading ${WhatsAppMetadata.whatsAppURL}...");
        await wpClient.loadUrl(WhatsAppMetadata.whatsAppURL);
        // Wait for page load
        await Future.delayed(const Duration(seconds: 5));
      }

      WhatsappLogger.log("WPP not found, fetching and injecting script content...");
      try {
        String content;
        if (wppJsContent != null) {
          content = wppJsContent;
        } else {
          try {
            content = await _fetchWppJs(version);
          } catch (e) {
            if (version == 'latest') rethrow;
            WhatsappLogger.log(
                "wa-js $version download failed ($e), trying latest release...");
            content = await _fetchWppJs('latest');
          }
        }

        // Inject the library as a string
        await wpClient.injectJs(content);
        WhatsappLogger.log("WPP script content injected, length: ${content.length}");
        
        // Give it a moment to parse and initialize
        await Future.delayed(const Duration(seconds: 1));
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
    await _configureWpp(wpClient, config: config, autoTakeover: autoTakeover);

    WhatsappLogger.log("WPP initialized and configured");
  }

  static Future<void> _configureWpp(
    WpClientInterface wpClient, {
    Map<String, dynamic>? config,
    bool autoTakeover = true,
  }) async {
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

    if (autoTakeover) {
      await wpClient.evaluateJs(
        '''
        if (typeof window.WPP !== 'undefined' && !window.__dragoTakeover) {
          window.__dragoTakeover = true;
          // Handle session takeover automatically
          window.WPP.on('conn.takeover', () => {
            console.log('Takeover detected, taking back control...');
            window.WPP.conn.takeover();
          });
        }
        ''',
        tryPromise: false,
      );
    }

    // Apply custom configs
    if (config != null) {
      for (var entry in config.entries) {
        await wpClient.evaluateJs(
          "window.WPP.config[${jsonEncode(entry.key)}] = ${jsonEncode(entry.value)};",
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
