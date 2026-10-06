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
    WhatsappLogger.log('Not authenticated and skipQrScan is true. Returning requireAuth status.');
    onConnectionEvent?.call(ConnectionEvent.requireAuth);
    return false;
  }

  if (!authenticated) {
    onConnectionEvent?.call(ConnectionEvent.waitingForQrScan);
    WhatsappLogger.log('Waiting for QRCode Scan...');

    final authCompleter = Completer<void>();
    void onAuthenticated(dynamic _) {
      if (!authCompleter.isCompleted) authCompleter.complete();
    }

    await wpClient.on(WhatsappEvent.connauthenticated, onAuthenticated);

    try {
      await Future.any([
        waitForQrCodeScan(
          wpClient: wpClient,
          onCatchQR: (QrCodeImage qrCodeImage, int attempt) {
            if (qrCodeImage.base64Image != null && qrCodeImage.urlCode != null) {
              Uint8List? imageBytes;
              try {
                final base64String = qrCodeImage.base64Image!.replaceFirst(
                    RegExp(r'data:image\/[a-zA-Z]+;base64,'), "");
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
      await wpClient.off(WhatsappEvent.connauthenticated, onAuthenticated);
    }

    WhatsappLogger.log('Checking login status after scan...');
    // Small delay to let internal state settle
    await Future.delayed(const Duration(milliseconds: 200));
    authenticated = await wppAuth.isAuthenticated();

    if (!authenticated) {
      throw const WhatsappException(
        message: 'Login Failed: Not authenticated after scan',
        exceptionType: WhatsappExceptionType.loginFailed,
      );
    }
  }

  onConnectionEvent?.call(ConnectionEvent.authenticated);
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

/// Waits up to two minutes for the chat screen. One check at a time -- a
/// slow check is never overlapped by the next one -- and a single page
/// reload at 70s, after which WPP is injected again with the same version
/// and config and the listeners are re-attached.
Future<bool> waitForInChat(
  WpClientInterface wpClient, {
  String? wppVersion,
  String? wppJsContent,
  Map<String, dynamic>? wppConfig,
  bool autoTakeover = true,
}) async {
  final wppAuth = WppAuth(wpClient);
  var readyEvent = false;
  void onReady(dynamic _) => readyEvent = true;

  // Fast-track if already ready
  if (await wppAuth.isMainReady()) return true;

  await wpClient.on(WhatsappEvent.connmainready, onReady);
  var startTime = DateTime.now();
  bool reloaded = false;

  try {
    while (true) {
      if (readyEvent) return true;
      final seconds = DateTime.now().difference(startTime).inSeconds;
      if (seconds >= 120) return false;

      try {
        if (await wppAuth.isMainReady()) return true;

        final isLoaded = await wppAuth.isMainLoaded();
        final isSynced = await wppAuth.isSynced();

        // Loaded and synced, or loaded for long enough
        if (isLoaded && (isSynced || seconds > 10)) {
          WhatsappLogger.log(
              "Main identity ready (Early via Loaded: $isLoaded, Synced: $isSynced)");
          return true;
        }

        if (seconds > 70 && !reloaded) {
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

        if (seconds > 0 && seconds % 10 == 0) {
          final isAuth = await wppAuth.isAuthenticated();
          if (!isAuth) {
            WhatsappLogger.log("Authentication lost while waiting for main.");
            return false;
          }
          WhatsappLogger.log(
              "Waiting for main ready... (Auth: OK, Loaded: $isLoaded, Synced: $isSynced, Time: $seconds/120s)");
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
