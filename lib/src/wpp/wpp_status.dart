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
    await _injectFileData(fileData);
    try {
      return await wpClient.evaluateJs(
        '''window.WPP.status.sendImageStatus(window.__wpp_file_data, {
          caption: ${caption.jsParse}
        });''',
        methodName: "sendImageStatus",
      );
    } finally {
      await _cleanupFileData();
    }
  }

  /// Send a video status
  Future sendVideoStatus({
    required List<int> fileBytes,
    String? caption,
  }) async {
    String base64Video = base64Encode(fileBytes);
    String fileData = "data:video/mp4;base64,$base64Video";
    await _injectFileData(fileData);
    try {
      return await wpClient.evaluateJs(
        '''window.WPP.status.sendVideoStatus(window.__wpp_file_data, {
          caption: ${caption.jsParse}
        });''',
        methodName: "sendVideoStatus",
      );
    } finally {
      await _cleanupFileData();
    }
  }

  /// Inject file data into a JS variable, chunking if necessary.
  /// For large files, uses array-based collection to avoid O(n²)
  /// string concatenation.
  Future<void> _injectFileData(String fileData) async {
    const int chunkSize = 2 * 1024 * 1024; // 2MB chunks
    if (fileData.length > chunkSize) {
      await wpClient.evaluateJs(
        'window.__wpp_file_chunks = [];',
        tryPromise: false,
      );
      for (int i = 0; i < fileData.length; i += chunkSize) {
        final end =
            (i + chunkSize > fileData.length) ? fileData.length : i + chunkSize;
        final chunk = fileData.substring(i, end);
        await wpClient.evaluateJs(
          'window.__wpp_file_chunks.push(${chunk.jsParse});',
          tryPromise: false,
        );
      }
      await wpClient.evaluateJs(
        'window.__wpp_file_data = window.__wpp_file_chunks.join(""); delete window.__wpp_file_chunks;',
        tryPromise: false,
      );
    } else {
      await wpClient.evaluateJs(
        'window.__wpp_file_data = ${fileData.jsParse};',
        tryPromise: false,
      );
    }
  }

  /// Clean up the temporary JS variable
  Future<void> _cleanupFileData() async {
    await wpClient.evaluateJs(
      'delete window.__wpp_file_data;',
      tryPromise: false,
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
