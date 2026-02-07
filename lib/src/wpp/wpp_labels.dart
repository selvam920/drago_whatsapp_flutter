import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppLabels {
  WpClientInterface wpClient;
  WppLabels(this.wpClient);

  /// Get all available labels
  Future getAllLabels() async {
    return await wpClient.evaluateJs(
      '''window.WPP.labels.list();''',
      methodName: "getAllLabels",
      forceJsonParseResult: true,
    );
  }

  /// Create a new label
  Future addNewLabel({
    required String labelName,
    String? labelColor,
  }) async {
    return await wpClient.evaluateJs(
      '''window.WPP.labels.addNewLabel(${labelName.jsParse}, {
        labelColor: ${labelColor.jsParse}
      });''',
      methodName: "addNewLabel",
    );
  }

  /// Delete a label
  Future deleteLabel({required String labelId}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.labels.deleteLabel(${labelId.jsParse});''',
      methodName: "deleteLabel",
    );
  }

  /// Add labels to specific chats
  Future addOrRemoveLabels({
    required List<String> labelIds,
    required List<String> chatIds,
  }) async {
    List<String> parsedChatIds = chatIds.map((e) => e.phoneParse).toList();
    return await wpClient.evaluateJs(
      '''window.WPP.labels.addOrRemoveLabels($labelIds, $parsedChatIds);''',
      methodName: "addOrRemoveLabels",
    );
  }
}
