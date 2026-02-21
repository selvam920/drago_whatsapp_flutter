// ignore_for_file: empty_catches

import 'dart:async';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

///[qrCodeImage] will give us a Stream of QrCode
/// call init method with page
Future<void> waitForQrCodeScan({
  required WpClientInterface wpClient,
  int waitDurationSeconds = 60,
  Function(QrCodeImage, int)? onCatchQR,
}) async {
  String? urlCode;
  int attempt = 0;
  final startTime = DateTime.now();

  // Add a listener for QR code change to be more reactive
  try {
    wpClient.on(WhatsappEvent.connauthcodechange, (data) async {
      final result = await wpClient.getQrCode();
      if (result != null && result.urlCode != urlCode) {
        urlCode = result.urlCode;
        attempt++;
        onCatchQR?.call(result, attempt);
      }
    });
  } catch (e) {
    WhatsappLogger.log("Failed to set QR code change listener: $e");
  }

  try {
    while (true) {
      if (DateTime.now().difference(startTime).inSeconds > waitDurationSeconds) {
        throw const WhatsappException(
          message: 'Timeout waiting for QR code scan',
          exceptionType: WhatsappExceptionType.timeout,
        );
      }

      final authenticated = await WppAuth(wpClient).isAuthenticated();
      if (authenticated) {
        break;
      }

      final result = await wpClient.getQrCode();
      final code = result?.urlCode;

      if (result != null && code != null && code != urlCode) {
        urlCode = code;
        attempt++;
        WhatsappLogger.log('Waiting for QRCode Scan: Attempt $attempt');
        onCatchQR?.call(result, attempt);
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  } finally {
    wpClient.off(WhatsappEvent.connauthcodechange);
  }
}
