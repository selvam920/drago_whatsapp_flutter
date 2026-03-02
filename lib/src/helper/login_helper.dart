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
}) async {
  WhatsappLogger.log('Checking authentication status...');
  final wppAuth = WppAuth(wpClient);

  bool authenticated = await wppAuth.isAuthenticated();

  if (!authenticated && skipQrScan) {
    WhatsappLogger.log('Authentication required but skipQrScan is true. Skipping login.');
    onConnectionEvent?.call(ConnectionEvent.disconnected);
    return false;
  }

  if (!authenticated) {
    onConnectionEvent?.call(ConnectionEvent.waitingForQrScan);
    WhatsappLogger.log('Waiting for QRCode Scan...');

    final authCompleter = Completer<void>();
    wpClient.on(WhatsappEvent.connauthenticated, (_) {
      if (!authCompleter.isCompleted) authCompleter.complete();
    });

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
      wpClient.off(WhatsappEvent.connauthenticated);
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
  final isReady = await waitForInChat(wpClient);
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

Future<bool> waitForInChat(WpClientInterface wpClient) async {
  final wppAuth = WppAuth(wpClient);
  final readyCompleter = Completer<bool>();
  var startTime = DateTime.now();
  int seconds = 0;
  bool reloaded = false;

  // Listen for the ready event to complete immediately
  wpClient.on(WhatsappEvent.connmainready, (_) {
    if (!readyCompleter.isCompleted) readyCompleter.complete(true);
  });

  // Fast-track if already ready
  if (await wppAuth.isMainReady()) {
    wpClient.off(WhatsappEvent.connmainready);
    return true;
  }

  try {
    // Polling as a fallback and for status updates
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (readyCompleter.isCompleted) {
        timer.cancel();
        return;
      }

      seconds = DateTime.now().difference(startTime).inSeconds;

      if (seconds >= 120) {
        if (!readyCompleter.isCompleted) readyCompleter.complete(false);
        timer.cancel();
        return;
      }

      try {
        if (await wppAuth.isMainReady()) {
          if (!readyCompleter.isCompleted) readyCompleter.complete(true);
          return;
        }

        final isLoaded = await wppAuth.isMainLoaded();
        final isSynced = await wppAuth.isSynced();

        // If loaded and synced, or loaded and wait for a short period (10s instead of 25s)
        if (isLoaded && (isSynced || seconds > 10)) {
          WhatsappLogger.log(
              "Main identity ready (Early via Loaded: $isLoaded, Synced: $isSynced)");
          if (!readyCompleter.isCompleted) readyCompleter.complete(true);
          return;
        }

        if (seconds > 70 && !reloaded) {
          WhatsappLogger.log(
              "Connection seems stuck. Attempting a page reload for recovery...");
          await wpClient.reload();
          reloaded = true;
          // Reset timer after reload
          startTime = DateTime.now();
          await Future.delayed(const Duration(seconds: 5));
          await WppConnect.init(wpClient);
        }

        if (seconds % 10 == 0) {
          final isAuth = await wppAuth.isAuthenticated();
          if (!isAuth) {
            WhatsappLogger.log("Authentication lost while waiting for main.");
            if (!readyCompleter.isCompleted) readyCompleter.complete(false);
            return;
          }
          WhatsappLogger.log(
              "Waiting for main ready... (Auth: OK, Loaded: $isLoaded, Synced: $isSynced, Time: $seconds/120s)");
        }
      } catch (e) {
        // Silent error in loop
      }
    });

    return await readyCompleter.future;
  } finally {
    wpClient.off(WhatsappEvent.connmainready);
  }
}
