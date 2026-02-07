import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drago_whatsapp_flutter/src/helper/qr_code_helper.dart';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

/// [waitForLogin] will either complete with successful login
/// or failed with timeout exception
/// this method will automatically try to get the qrCode
/// also it will make sure that we get the latest qrCode
Future<void> waitForLogin(
  WpClientInterface wpClient, {
  required Function(String qrCodeUrl, Uint8List? qrCodeImage)? onQrCode,
  int waitDurationSeconds = 60,
  Function(ConnectionEvent)? onConnectionEvent,
}) async {
  WhatsappLogger.log('Checking authentication status...');
  final wppAuth = WppAuth(wpClient);

  bool authenticated = await wppAuth.isAuthenticated();

  if (!authenticated) {
    onConnectionEvent?.call(ConnectionEvent.waitingForQrScan);
    WhatsappLogger.log('Waiting for QRCode Scan...');

    try {
      await waitForQrCodeScan(
        wpClient: wpClient,
        onCatchQR: (QrCodeImage qrCodeImage, int attempt) {
          if (qrCodeImage.base64Image != null && qrCodeImage.urlCode != null) {
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
      );
    } catch (e) {
      if (e is WhatsappException) rethrow;
      throw WhatsappException(
        message: "Error during QR scan: $e",
        exceptionType: WhatsappExceptionType.unknown,
      );
    }

    WhatsappLogger.log('Checking login status after scan...');
    // Give it a moment to process authentication
    await Future.delayed(const Duration(seconds: 1));
    authenticated = await wppAuth.isAuthenticated();

    if (!authenticated) {
      throw const WhatsappException(
        message: 'Login Failed: Not authenticated after scan',
        exceptionType: WhatsappExceptionType.loginFailed,
      );
    }
  }

  onConnectionEvent?.call(ConnectionEvent.authenticated);
  await Future.delayed(const Duration(milliseconds: 500));

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
}

Future<bool> waitForInChat(WpClientInterface wpClient) async {
  final wppAuth = WppAuth(wpClient);
  var startTime = DateTime.now();
  int seconds = 0;
  bool reloaded = false;

  while (seconds < 120) {
    seconds = DateTime.now().difference(startTime).inSeconds;
    try {
      // Primary check: Is the main interface fully ready?
      if (await wppAuth.isMainReady()) {
        WhatsappLogger.log("Main identity ready (Full)");
        return true;
      }

      // Secondary check: Is it simply loaded? 
      // If synced is true, we can probably proceed faster
      final isLoaded = await wppAuth.isMainLoaded();
      final isSynced = await wppAuth.isSynced();

      if (isLoaded && (isSynced || seconds > 25)) {
        WhatsappLogger.log(
            "Main identity ready (Early via Loaded: $isLoaded, Synced: $isSynced)");
        return true;
      }

      // Recovery: If we are authenticated but stuck for > 60 seconds, try a single reload
      if (seconds > 70 && !reloaded) {
        WhatsappLogger.log(
            "Connection seems stuck. Attempting a page reload for recovery...");
        await wpClient.reload();
        reloaded = true;
        // Reset timer after reload to give it fresh time
        startTime = DateTime.now();
        // Wait for page to reload and re-initialize WPP
        await Future.delayed(const Duration(seconds: 10));
        await WppConnect.init(wpClient);
        continue;
      }

      if (seconds % 60 == 0 && seconds > 0) {
        WhatsappLogger.log("Long wait usually means WhatsApp is syncing your chat history. Please ensure your phone is online.");
      }

      if (seconds % 10 == 0 && seconds > 0) {
        final isAuth = await wppAuth.isAuthenticated();
        final isLoaded = await wppAuth.isMainLoaded();
        final isSynced = await wppAuth.isSynced();
        if (!isAuth) {
          WhatsappLogger.log("Authentication lost while waiting for main.");
          return false;
        }
        WhatsappLogger.log("Waiting for main ready... (Auth: OK, Loaded: $isLoaded, Synced: $isSynced)");
      }
    } catch (e) {
      WhatsappLogger.log("Error during connection loop: $e");
    }

    WhatsappLogger.log("Waiting for main ready... ($seconds/120s)");
    await Future.delayed(const Duration(seconds: 2));
  }
  return false;
}
