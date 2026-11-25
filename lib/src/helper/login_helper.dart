import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drago_whatsapp_flutter/src/helper/qr_code_helper.dart';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

/// [waitForLogin] will either complete with successful login
/// or failed with timeout exception
/// this method will automatically try to get the qrCode
/// also it will make sure that we get the latest qrCode
/// Returns `true` if login succeeded, `false` if login was skipped
/// because [skipQrScan] is true and the user is not authenticated.
Future<bool> waitForLogin(
  WpClientInterface wpClient, {
  required Function(String qrCodeUrl, Uint8List? qrCodeImage)? onQrCode,
  int waitDurationSeconds = 60,
  Function(ConnectionEvent)? onConnectionEvent,
  bool skipQrScan = false,
  String? wppVersion,
  String? wppJsContent,
  Map<String, dynamic>? wppConfig,
  bool autoTakeover = true,
}) async {
  WhatsappLogger.log('Checking authentication status...');
  final wppAuth = WppAuth(wpClient);

  // Brief delay to let the page and WPP state settle
  await Future.delayed(const Duration(milliseconds: 500));
  bool authenticated = await wppAuth.isAuthenticated();

  if (!authenticated && skipQrScan) {
    WhatsappLogger.log(
        'Not authenticated and skipQrScan is true. Returning requireAuth status.');
    onConnectionEvent?.call(ConnectionEvent.requireAuth);
    return false;
  }

  // A new login: the chat load after the scan gets a longer budget than a
  // restart, where the chats are already on this computer.
  var freshLogin = false;

  if (!authenticated) {
    freshLogin = true;
    onConnectionEvent?.call(ConnectionEvent.waitingForQrScan);
    WhatsappLogger.log('Waiting for QRCode Scan...');

    final authCompleter = Completer<void>();
    void onAuthenticated(dynamic _) {
      if (!authCompleter.isCompleted) authCompleter.complete();
    }

    await wpClient.on(WhatsappEvent.connauthenticated, onAuthenticated);

    // Set once the scan is seen (either way): the QR wait must not show a
    // QR after it, even while Future.any has already moved on.
    var scanSeen = false;
    try {
      await Future.any([
        waitForQrCodeScan(
          wpClient: wpClient,
          isStopped: () => scanSeen || authCompleter.isCompleted,
          onCatchQR: (QrCodeImage qrCodeImage, int attempt) {
            if (scanSeen || authCompleter.isCompleted) return;
            if (qrCodeImage.base64Image != null &&
                qrCodeImage.urlCode != null) {
              Uint8List? imageBytes;
              try {
                final base64String = qrCodeImage.base64Image!
                    .replaceFirst(RegExp(r'data:image\/[a-zA-Z]+;base64,'), "");
                imageBytes = base64Decode(base64String);
              } catch (e) {
                WhatsappLogger.log("Error decoding QR image: $e");
              }
              onQrCode?.call(qrCodeImage.urlCode!, imageBytes);
            }
          },
          waitDurationSeconds: waitDurationSeconds,
        ),
        authCompleter.future,
      ]);
    } catch (e) {
      if (e is WhatsappException) rethrow;
      throw WhatsappException(
        message: "Error during QR scan: $e",
        exceptionType: WhatsappExceptionType.unknown,
      );
    } finally {
      scanSeen = true;
      await wpClient.off(WhatsappEvent.connauthenticated, onAuthenticated);
    }

    // The phone already shows this computer as linked: tell the app now,
    // so it drops the QR while the chats load.
    onConnectionEvent?.call(ConnectionEvent.authenticated);

    WhatsappLogger.log('Checking login status after scan...');
    // WhatsApp Web reloads its page right after a scan; wa-js comes back
    // with ensureInjected. Give it time before calling the login failed.
    if (!await _confirmLinked(wpClient, const Duration(seconds: 20))) {
      throw const WhatsappException(
        message: 'Login Failed: Not authenticated after scan',
        exceptionType: WhatsappExceptionType.loginFailed,
      );
    }
  } else {
    onConnectionEvent?.call(ConnectionEvent.authenticated);
  }

  await Future.delayed(const Duration(milliseconds: 200));

  WhatsappLogger.log('Waiting for connection to be ready...');
  onConnectionEvent?.call(ConnectionEvent.connecting);

  // Wait for main interface to be ready
  final isReady = await waitForInChat(
    wpClient,
    wppVersion: wppVersion,
    wppJsContent: wppJsContent,
    wppConfig: wppConfig,
    autoTakeover: autoTakeover,
    // A new login downloads the chat history first; a restart only opens
    // the chats already on this computer.
    timeoutSeconds: freshLogin ? 240 : 120,
    reloadAfterSeconds: freshLogin ? 120 : 70,
  );
  if (!isReady) {
    throw const WhatsappException(
      message: 'Connection failed: Main interface not ready',
      exceptionType: WhatsappExceptionType.connectionFailed,
    );
  }

  WhatsappLogger.log('Connected successfully');
  onConnectionEvent?.call(ConnectionEvent.connected);
  return true;
}

/// Right after a scan: is the device linked? WhatsApp Web reloads its page
/// then, so a missing wa-js is put back (not taken as a failure), and the
/// page gets [within] to say so.
Future<bool> _confirmLinked(WpClientInterface wpClient, Duration within) async {
  final until = DateTime.now().add(within);
  while (true) {
    final state = await LoginPageState.read(wpClient);
    if (state.authenticated || state.registered) return true;
    if (state.wpp &&
        (state.streamMode == 'SYNCING' || state.streamMode == 'MAIN')) {
      return true;
    }
    if (DateTime.now().isAfter(until)) {
      WhatsappLogger.log('Not linked after scan ($state)');
      return false;
    }
    if (!state.wpp && !state.loading) {
      try {
        await WppConnect.ensureInjected(wpClient);
      } catch (e) {
        WhatsappLogger.log('Re-inject after scan failed: $e');
      }
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }
}

/// Waits up to [timeoutSeconds] for the chat screen. One check at a time --
/// a slow check is never overlapped by the next one -- and a single page
/// reload at [reloadAfterSeconds], after which WPP is injected again with
/// the same version and config and the listeners are re-attached.
///
/// A page that reloads by itself (WhatsApp Web does after a scan) loses
/// wa-js: it is put back, never read as a lost login. Only a page back on
/// the QR screen counts as lost.
Future<bool> waitForInChat(
  WpClientInterface wpClient, {
  String? wppVersion,
  String? wppJsContent,
  Map<String, dynamic>? wppConfig,
  bool autoTakeover = true,
  int timeoutSeconds = 120,
  int reloadAfterSeconds = 70,
}) async {
  final wppAuth = WppAuth(wpClient);
  var readyEvent = false;
  void onReady(dynamic _) => readyEvent = true;

  // Fast-track if already ready
  if (await wppAuth.isMainReady()) return true;

  await wpClient.on(WhatsappEvent.connmainready, onReady);
  var startTime = DateTime.now();
  bool reloaded = false;
  int lostChecks = 0;

  try {
    while (true) {
      if (readyEvent) return true;
      final seconds = DateTime.now().difference(startTime).inSeconds;
      if (seconds >= timeoutSeconds) return false;

      try {
        final state = await LoginPageState.read(wpClient);
        if (!state.wpp) {
          if (!state.loading) {
            WhatsappLogger.log(
                "WPP gone while waiting for main (page reloaded), injecting again");
            try {
              await WppConnect.ensureInjected(wpClient);
            } catch (e) {
              WhatsappLogger.log("Re-inject while waiting for main failed: $e");
            }
          }
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        if (await wppAuth.isMainReady()) return true;

        final isLoaded = await wppAuth.isMainLoaded();
        final isSynced = await wppAuth.isSynced();

        // Loaded and synced, or loaded for long enough
        if (isLoaded && (isSynced || seconds > 10)) {
          WhatsappLogger.log(
              "Main identity ready (Early via Loaded: $isLoaded, Synced: $isSynced)");
          return true;
        }

        if (seconds > reloadAfterSeconds && !reloaded) {
          WhatsappLogger.log(
              "Connection seems stuck. Attempting a page reload for recovery...");
          reloaded = true;
          await wpClient.reload();
          await Future.delayed(const Duration(seconds: 5));
          await WppConnect.init(
            wpClient,
            wppVersion: wppVersion,
            wppJsContent: wppJsContent,
            config: wppConfig,
            autoTakeover: autoTakeover,
          );
          await wpClient.restoreListeners();
          startTime = DateTime.now();
          continue;
        }

        // Back on the QR screen, a few checks in a row: the link is gone.
        lostChecks = state.showsQr ? lostChecks + 1 : 0;
        if (lostChecks >= 5) {
          WhatsappLogger.log("Authentication lost while waiting for main.");
          return false;
        }

        if (seconds > 0 && seconds % 10 == 0) {
          WhatsappLogger.log(
              "Waiting for main ready... ($state, Loaded: $isLoaded, Synced: $isSynced, Time: $seconds/${timeoutSeconds}s)");
        }
      } catch (e) {
        WhatsappLogger.log("waitForInChat check failed: $e");
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  } finally {
    try {
      await wpClient.off(WhatsappEvent.connmainready, onReady);
    } catch (_) {}
  }
}
