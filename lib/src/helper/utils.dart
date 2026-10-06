import 'dart:convert';
import 'dart:developer' as developer;

import 'package:mime/mime.dart';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:zxing2/qrcode.dart';

class WhatsappLogger {
  static bool enableLogger = false;

  static Function(dynamic)? handleLogs;

  static void log(dynamic log) {
    if (!enableLogger) return;
    if (handleLogs != null) {
      handleLogs?.call(log);
    } else {
      developer.log(log.toString(), name: 'WhatsappBotFlutter');
    }
  }
}

class WhatsAppMetadata {
  static String whatsAppURL = "https://web.whatsapp.com/";
  // "web.whatsapp.com/🌎/en/";
  static String whatsAppURLForceDesktop = "web.whatsapp.com//";
  static String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
}

class WhatsappBotUtils {
  /// [convertStringToQrCode] will convert a Text into a qrCode , which we can print in Terminal
  /// used in scanning code from terminal if we are using this in pure Dart project
  static String convertStringToQrCode(String text) {
    var qrCode = Encoder.encode(text, ErrorCorrectionLevel.l);
    var matrix = qrCode.matrix!;
    var stringBuffer = StringBuffer();
    for (var y = 0; y < matrix.height; y += 2) {
      for (var x = 0; x < matrix.width; x++) {
        final y1 = matrix.get(x, y) == 1;
        final y2 = (y + 1 < matrix.height) ? matrix.get(x, y + 1) == 1 : false;

        if (y1 && y2) {
          stringBuffer.write('█');
        } else if (y1) {
          stringBuffer.write('▀');
        } else if (y2) {
          stringBuffer.write('▄');
        } else {
          stringBuffer.write(' ');
        }
      }
      stringBuffer.writeln();
    }
    return stringBuffer.toString();
  }

  /// To print logs from this library set `enableLogs(true)`, by default its false
  static void enableLogs(bool enable) {
    WhatsappLogger.enableLogger = enable;
  }
}

// /// [validateMessage] will verify if data passed is correct or not
Future validateConnection(WpClientInterface wpClient) async {
  if (!wpClient.isConnected()) {
    throw WhatsappException(
        message: "WhatsappClient no connected , please reconnect",
        exceptionType: WhatsappExceptionType.clientNotConnected);
  }

  bool isAuthenticated = await WppAuth(wpClient).isAuthenticated();
  if (!isAuthenticated) {
    throw WhatsappException(
        message: "Please login first",
        exceptionType: WhatsappExceptionType.unAuthorized);
  }
}

/// Use [JsParse] extension on data we pass in Javascript string.
///
/// Strings, numbers, booleans, lists and maps become JSON literals, so quotes,
/// backslashes and control characters in user text can never break out of the
/// generated script. `null` stays `null` (it interpolates as the JS literal).
extension JsParser on dynamic {
  dynamic get jsParse {
    final value = this;
    if (value == null) return null;
    if (value is String ||
        value is num ||
        value is bool ||
        value is List ||
        value is Map) {
      return jsonEncode(value);
    }
    return value;
  }

  String get phoneParse => jsonEncode(parsePhone(this));

  String get groupParse => jsonEncode(parseGroup(this));
}

/// Digits only, for a number typed with spaces, dashes, brackets or `+`.
String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

/// [parsePhone] will try to convert phone number in required format.
/// A full chat id (`...@c.us`, `...@g.us`, `...@newsletter`, `...@lid`)
/// is passed through unchanged, so groups and channels can be sent to with
/// the same methods.
String parsePhone(String phone) {
  final trimmed = phone.trim();
  if (trimmed.contains("@")) return trimmed;
  return "${_digits(trimmed)}@c.us";
}

/// [parseGroup] will try to convert group number in required format
String parseGroup(String phone) {
  final trimmed = phone.trim();
  if (trimmed.contains("@")) return trimmed;
  return "${trimmed.replaceAll(RegExp(r'[^0-9-]'), '')}@g.us";
}

/// [getMimeType] returns the MIME type for the given file.
/// Tries to detect from [fileName] first using the `mime` package,
/// then falls back to defaults based on [fileType].
String getMimeType(
  WhatsappFileType fileType,
  String? fileName,
  List<int> bytes,
) {
  // Try to detect MIME type from the actual file name/extension first
  if (fileName != null) {
    String? detected = lookupMimeType(fileName, headerBytes: bytes);
    if (detected != null) return detected;
  }

  // Fall back to defaults based on the declared file type
  switch (fileType) {
    case WhatsappFileType.document:
      return "application/msword";
    case WhatsappFileType.pdf:
      return "application/pdf";
    case WhatsappFileType.image:
      return "image/jpeg";
    case WhatsappFileType.audio:
      return "audio/mp3";
    case WhatsappFileType.video:
      return "video/mp4";
    case WhatsappFileType.unknown:
      return "application/octet-stream";
  }
}

Map<String, dynamic> base64ToMap(String base64String) {
  List<String> data = base64String.split(";");
  Map<String, dynamic> map = {};
  for (String value in data) {
    if (value.startsWith("base64,")) {
      map["base64"] = value.replaceAll("base64,", "");
    } else if (value.startsWith("data")) {
      map["data"] = value.replaceAll("data:", "");
    } else if (value.contains("=")) {
      var s = value.split("=");
      if (s.isNotEmpty) {
        map[s[0]] = s[1];
      }
    }
  }
  return map;
}
