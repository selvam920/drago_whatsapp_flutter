import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppGroup {
  WpClientInterface wpClient;
  WppGroup(this.wpClient);

  /// To add participants to a group
  Future createGroup({required String groupName}) async {
    return await wpClient.evaluateJs('''
        window.WPP.group.create(${groupName.jsParse} , []);
      ''', methodName: "createGroup");
  }

  /// To get participants of a group
  Future getParticipants({required String groupId}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.group.getParticipants(${groupId.groupParse});''',
      methodName: "getParticipants",
      forceJsonParseResult: true,
    );
  }

  /// To get all groups
  Future getAllGroups() async {
    return await wpClient.evaluateJs(
      '''window.WPP.group.getAllGroups();''',
      methodName: "getAllGroups",
      forceJsonParseResult: true,
    );
  }

  /// Set the group subject
  Future setSubject({
    required String groupId,
    required String subject,
  }) async {
    return wpClient.evaluateJs(
      '''window.WPP.group.setSubject(${groupId.groupParse}, ${subject.jsParse});''',
      methodName: 'setSubject',
    );
  }

  /// To add participants to a group
  Future addParticipants({
    required String groupId,
    required List<String> phoneNumbers,
  }) async {
    List<String> parseList = phoneNumbers.map((e) => e.phoneParse).toList();
    return await wpClient.evaluateJs(
      '''window.WPP.group.addParticipants(${groupId.groupParse},$parseList);''',
      methodName: "addParticipants",
    );
  }

  /// To reomve participants from a group
  Future removeParticipants({
    required String groupId,
    required List<String> phoneNumbers,
  }) async {
    List<String> parseList = phoneNumbers.map((e) => e.phoneParse).toList();
    return await wpClient.evaluateJs(
      '''window.WPP.group.removeParticipants(${groupId.groupParse}, $parseList);''',
      methodName: "removeParticipants",
    );
  }
}
