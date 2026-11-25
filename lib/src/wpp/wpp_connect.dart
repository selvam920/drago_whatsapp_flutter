// Thanks to https://github.com/wppconnect-team/wa-js

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppConnect {
  /// The wa-js release used when the app names none. Pinned so an upstream
  /// release can't change every installation overnight; bump it after testing
  /// a new release. When this download fails the latest release is tried.
  ///
  /// v4.7.1 follows WhatsApp Web moving prepRawMedia out of WAWebMediaPrep,
  /// which file sends depend on.
  static const String defaultWppVersion = 'v4.7.1';

  static final Map<String, String> _cachedWppJs = {};

  /// What each client was last initialised with, so [ensureReady] can put
  /// wa-js back the same way after WhatsApp Web reloads its page.
  static final Expando<_InitArgs> _initArgs = Expando('wppInitArgs');

  /// Before a send: WhatsApp Web reloads itself (updates, a stuck socket),
  /// and a reload drops the injected wa-js -- every send then failed with
  /// "Cannot read properties of undefined (reading 'chat')" until the bot
  /// was reconnected. Re-injects when `window.WPP` is gone or not ready.
  /// One re-injection at a time per client: the watchdog and sends racing
  /// on a missing WPP used to inject wa-js twice.
  static final Expando<Future<void>> _ensuring = Expando('wppEnsuring');

  /// A logout is reported once per unlink (cleared by [markLinked]).
  static final Expando<bool> _logoutReported = Expando('wppLogoutReported');

  static Future<void> ensureReady(WpClientInterface wpClient) {
    final running = _ensuring[wpClient];
    if (running != null) return running;
    final run = _ensureReady(wpClient);
    _ensuring[wpClient] = run;
    return run.whenComplete(() => _ensuring[wpClient] = null);
  }

  static Future<void> _ensureReady(WpClientInterface wpClient) async {
    await ensureInjected(wpClient);
    if (await linkState(wpClient) == WppLinkState.loggedOut) {
      // WhatsApp unlinked this device (phone offline ~14 days, removed
      // under Linked devices, a security check). Tell the app, so it shows
      // the QR again, and fail the send in plain words.
      await reportLogout(wpClient);
      throw const WhatsappException(
        exceptionType: WhatsappExceptionType.unAuthorized,
        message: 'WhatsApp is logged out on this device. '
            'Open WhatsApp settings and scan the QR code again.',
      );
    }
  }

  /// One re-injection at a time per client (see [_ensuring]).
  static final Expando<Future<void>> _injecting = Expando('wppInjecting');

  /// Puts wa-js back -- same version, config and listeners as the last
  /// [init] -- when the page lost it (WhatsApp Web reloaded). Unlike
  /// [ensureReady] it never reports or throws a logout, so it is safe while
  /// a new login is still pairing.
  static Future<void> ensureInjected(WpClientInterface wpClient) {
    final running = _injecting[wpClient];
    if (running != null) return running;
    final run = _ensureInjected(wpClient);
    _injecting[wpClient] = run;
    return run.whenComplete(() => _injecting[wpClient] = null);
  }

  static Future<void> _ensureInjected(WpClientInterface wpClient) async {
    if (!wpClient.isConnected()) {
      // Disconnected: fail now instead of injecting into nothing and
      // waiting out the 60 s ready timeout.
      throw const WhatsappException(
        exceptionType: WhatsappExceptionType.clientNotConnected,
        message:
            'WhatsApp is not connected. Reconnect it in WhatsApp settings.',
      );
    }
    final ok = await wpClient.evaluateJs(
      "typeof window.WPP !== 'undefined' && !!window.WPP.isReady && "
      "!!window.WPP.chat;",
      tryPromise: false,
    );
    if (ok == true || ok?.toString() == 'true') return;
    WhatsappLogger.log('WPP missing (page reloaded?), injecting again');
    // A script injected into a page that is still loading is lost with it.
    for (var i = 0; i < 15; i++) {
      try {
        final state = await wpClient.evaluateJs(
          'document.readyState',
          tryPromise: false,
        );
        if (state?.toString() == 'complete') break;
      } catch (_) {
        // Between documents; ask again.
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    final args = _initArgs[wpClient] ?? const _InitArgs();
    await init(
      wpClient,
      wppJsContent: args.wppJsContent,
      wppVersion: args.wppVersion,
      config: args.config,
      autoTakeover: args.autoTakeover,
    );
    // The reload dropped the JS side of every listener too -- without
    // this a later logout from the phone never reached the app.
    await wpClient.restoreListeners();
  }

  /// Is the WhatsApp Web page linked, logged out, or without wa-js (gone)?
  static Future<WppLinkState> linkState(WpClientInterface wpClient) async {
    try {
      final r = await wpClient.evaluateJs(
        """(function() {
          if (typeof window.WPP === 'undefined' || !window.WPP.conn) return 'gone';
          try {
            if (!window.WPP.conn.isAuthenticated()) return 'out';
            // Linked but the socket is down (PC or phone offline).
            if (typeof window.WPP.conn.isOnline === 'function' &&
                window.WPP.conn.isOnline() === false) return 'offline';
            return 'ok';
          }
          catch (e) { return 'gone'; }
        })()""",
        tryPromise: false,
      );
      return switch (r?.toString()) {
        'ok' => WppLinkState.linked,
        'out' => WppLinkState.loggedOut,
        'offline' => WppLinkState.offline,
        _ => WppLinkState.gone,
      };
    } catch (_) {
      return WppLinkState.gone;
    }
  }

  /// Sends a connection event ([ConnectionEvent] name) through the normal
  /// event path.
  static Future<void> reportEvent(
    WpClientInterface wpClient,
    String event,
  ) async {
    try {
      await wpClient.evaluateJs(
        "if (typeof window.onCustomEvent === 'function') "
        "window.onCustomEvent('connectionEvent', '$event');",
        tryPromise: false,
      );
    } catch (_) {}
  }

  /// The device is linked again: a later unlink is reported anew.
  static void markLinked(WpClientInterface wpClient) =>
      _logoutReported[wpClient] = null;

  /// Sends the logout connection event through the normal event path, once
  /// per unlink however many sends and checks notice it.
  static Future<void> reportLogout(WpClientInterface wpClient) async {
    if (_logoutReported[wpClient] == true) return;
    _logoutReported[wpClient] = true;
    try {
      await wpClient.evaluateJs(
        "if (typeof window.onCustomEvent === 'function') "
        "window.onCustomEvent('connectionEvent', 'logout');",
        tryPromise: false,
      );
    } catch (_) {}
  }

  static String _releaseUrl(String version) => version == 'latest'
      ? "https://github.com/wppconnect-team/wa-js/releases/latest/download/wppconnect-wa.js"
      : "https://github.com/wppconnect-team/wa-js/releases/download/$version/wppconnect-wa.js";

  /// Downloads are kept in `sessionPath/wajs` so a restart doesn't download
  /// again and an offline PC still connects. A pinned release never changes,
  /// so its saved copy is used as-is; 'latest' always tries the download
  /// first and falls back to the saved copy.
  static File? _diskFile(String? cacheDir, String version) {
    if (cacheDir == null || cacheDir.isEmpty) return null;
    final name = version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('$cacheDir${Platform.pathSeparator}wajs'
        '${Platform.pathSeparator}$name.js');
  }

  /// GitHub's release hosts. Only these skip the certificate check, and only
  /// after a normal download failed on it.
  static const _scriptHosts = {
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  /// Downloads the release. A PC whose antivirus re-signs HTTPS (or has old
  /// root certificates) fails the certificate check; the script is then
  /// fetched again without it, from GitHub hosts only, so the bot still
  /// connects. The rest of the app keeps full certificate checks.
  static Future<String> _download(String version) async {
    final uri = Uri.parse(_releaseUrl(version));
    try {
      return await http.read(uri).timeout(const Duration(seconds: 30));
    } on HandshakeException catch (e) {
      WhatsappLogger.log("wa-js certificate check failed ($e), "
          "retrying without it for GitHub only");
    } on http.ClientException catch (e) {
      if (!e.message.contains('CERTIFICATE_VERIFY_FAILED') &&
          !e.message.contains('HandshakeException')) {
        rethrow;
      }
      WhatsappLogger.log("wa-js certificate check failed ($e), "
          "retrying without it for GitHub only");
    }
    final client = HttpClient()
      ..badCertificateCallback =
          (cert, host, port) => _scriptHosts.contains(host.toLowerCase());
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw HttpException('wa-js download returned ${res.statusCode}',
            uri: uri);
      }
      return await res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  static Future<String?> _readDisk(File? file) async {
    try {
      if (file == null || !await file.exists()) return null;
      final content = await file.readAsString();
      return content.length > 1000 ? content : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _fetchWppJs(String version, {String? cacheDir}) async {
    final cached = _cachedWppJs[version];
    if (cached != null) return cached;
    final file = _diskFile(cacheDir, version);
    if (version != 'latest') {
      final saved = await _readDisk(file);
      if (saved != null) return _cachedWppJs[version] = saved;
    }
    String content;
    try {
      content = await _download(version);
    } catch (_) {
      final saved = await _readDisk(file);
      if (saved == null) rethrow;
      WhatsappLogger.log("wa-js $version download failed, using saved copy");
      return _cachedWppJs[version] = saved;
    }
    _cachedWppJs[version] = content;
    if (file != null) {
      try {
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
      } catch (e) {
        WhatsappLogger.log("Could not save wa-js copy ($e)");
      }
    }
    return content;
  }

  /// The copy of [defaultWppVersion] bundled in assets/. Used for the default
  /// or 'latest' version only, never in place of another pinned release.
  static Future<String?> _bundledWppJs(String version) async {
    if (version != defaultWppVersion && version != 'latest') return null;
    try {
      final content = await rootBundle.loadString(
          'packages/drago_whatsapp_flutter/assets/wppconnect-wa.js');
      WhatsappLogger.log("Using bundled wa-js $defaultWppVersion");
      return content;
    } catch (e) {
      WhatsappLogger.log("Bundled wa-js not available ($e)");
      return null;
    }
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
    _initArgs[wpClient] = _InitArgs(
      wppJsContent: wppJsContent,
      wppVersion: wppVersion,
      config: config,
      autoTakeover: autoTakeover,
    );
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
      final currentUrl =
          await wpClient.evaluateJs("window.location.href", tryPromise: false);
      if (currentUrl != null &&
          !currentUrl.toString().contains("web.whatsapp.com")) {
        WhatsappLogger.log(
            "Not on WhatsApp Web page ($currentUrl), loading ${WhatsAppMetadata.whatsAppURL}...");
        await wpClient.loadUrl(WhatsAppMetadata.whatsAppURL);
        // Wait for page load
        await Future.delayed(const Duration(seconds: 5));
      }

      WhatsappLogger.log(
          "WPP not found, fetching and injecting script content...");
      try {
        String content;
        if (wppJsContent != null) {
          content = wppJsContent;
        } else {
          try {
            content =
                await _fetchWppJs(version, cacheDir: wpClient.sessionPath);
          } catch (e) {
            WhatsappLogger.log("wa-js $version download failed ($e)");
            // A PC whose certificate store can't verify GitHub (antivirus
            // HTTPS scanning, old root certificates) fails every download;
            // the pinned release ships with the package for that case.
            content = await _bundledWppJs(version) ??
                (version == 'latest'
                    ? throw e
                    : await _fetchWppJs('latest',
                        cacheDir: wpClient.sessionPath));
          }
        }

        // Inject the library as a string
        await wpClient.injectJs(content);
        WhatsappLogger.log(
            "WPP script content injected, length: ${content.length}");

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
    // WhatsApp now addresses people by LID. Sending to number@c.us for a
    // number this session never looked up fails with "No LID for user", so
    // every send resolves the number first: the lookup returns (and caches)
    // the LID, and a number without WhatsApp fails with a clear message.
    await wpClient.evaluateJs(
      '''
      window.__dragoResolve = async function(id) {
        if (!id || typeof id !== 'string' || !id.endsWith('@c.us')) return id;
        var query = window.WPP.contact.queryWidExists || window.WPP.contact.queryExists;
        var found = await query(id);
        if (!found) {
          throw new Error('Not on WhatsApp: ' + id.replace('@c.us', ''));
        }
        var lid = found.lid ? (found.lid._serialized || String(found.lid)) : null;
        var wid = found.wid ? (found.wid._serialized || String(found.wid)) : null;
        return lid || wid || id;
      };
      ''',
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
            WhatsappLogger.log(
                "WPP Status: count=$count, present=$present, isReady=$isReady, webpackReady=$webpackReady");
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

class _InitArgs {
  const _InitArgs({
    this.wppJsContent,
    this.wppVersion,
    this.config,
    this.autoTakeover = true,
  });

  final String? wppJsContent;
  final String? wppVersion;
  final Map<String, dynamic>? config;
  final bool autoTakeover;
}

/// See [WppConnect.linkState].
enum WppLinkState {
  linked,
  loggedOut,

  /// Linked, but WhatsApp's connection is down (no internet on the PC, or
  /// the phone unreachable). Sends would only wait out their timeout.
  offline,
  gone,
}
