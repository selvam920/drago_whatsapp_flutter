import 'dart:convert';

import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppStatus {
  WpClientInterface wpClient;
  WppStatus(this.wpClient);

  /// Send a text status to your status
  Future sendTextStatus({
    required String status,
    String? backgroundColor,
    String? font,
  }) async {
    return await wpClient.evaluateJs(
      '''window.WPP.status.sendTextStatus(${status.jsParse}, {
        backgroundColor: ${backgroundColor.jsParse},
        font: ${font.jsParse}
      });''',
      methodName: "sendTextStatus",
    );
  }

  /// Send an image status
  Future sendImageStatus({
    required List<int> fileBytes,
    String? caption,
  }) async {
    String base64Image = base64Encode(fileBytes);
    String fileData = "data:image/jpeg;base64,$base64Image";
    return await wpClient.evaluateJs(
      '''window.WPP.status.sendImageStatus(${fileData.jsParse}, {
        caption: ${caption.jsParse}
      });''',
      methodName: "sendImageStatus",
    );
  }

  /// Send a video status
  Future sendVideoStatus({
    required List<int> fileBytes,
    String? caption,
  }) async {
    String base64Video = base64Encode(fileBytes);
    String fileData = "data:video/mp4;base64,$base64Video";
    return await wpClient.evaluateJs(
      '''window.WPP.status.sendVideoStatus(${fileData.jsParse}, {
        caption: ${caption.jsParse}
      });''',
      methodName: "sendVideoStatus",
    );
  }

  /// Get status of your own account
  Future getMyStatus() async {
    return await wpClient.evaluateJs(
      '''window.WPP.status.getMyStatus();''',
      methodName: "getMyStatus",
      forceJsonParseResult: true,
    );
  }

  /// List all status updates from contacts
  Future getAllStatus() async {
    return await wpClient.evaluateJs(
      '''window.WPP.status.list();''',
      methodName: "getAllStatus",
      forceJsonParseResult: true,
    );
  }
}
