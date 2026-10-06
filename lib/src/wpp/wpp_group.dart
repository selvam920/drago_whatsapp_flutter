import 'dart:convert';

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

  /// Groups this account is in, light enough for a picker. Pass an item's
  /// `id` as the `phone` of any chat send method.
  Future<List<WhatsappChatSummary>> list() async {
    final result = await wpClient.evaluateJs(
      '''(async function() {
        var chats = await window.WPP.chat.list({onlyGroups: true});
        return chats.map(function(c) {
          var meta = c.groupMetadata || {};
          var admin = null;
          try {
            if (meta.participants && typeof meta.participants.iAmAdmin === 'function') {
              admin = !!meta.participants.iAmAdmin();
            }
          } catch (e) {}
          var count = null;
          try { count = meta.participants ? meta.participants.length : null; } catch (e) {}
          return {
            id: c.id && c.id._serialized ? c.id._serialized : String(c.id),
            name: c.name || meta.subject || c.formattedTitle || '',
            announce: !!meta.announce,
            isAdmin: admin,
            memberCount: count
          };
        });
      })()''',
      methodName: "groupList",
    );
    return WhatsappChatSummary.parseList(result);
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
    final parseList = jsonEncode(phoneNumbers.map(parsePhone).toList());
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
    final parseList = jsonEncode(phoneNumbers.map(parsePhone).toList());
    return await wpClient.evaluateJs(
      '''window.WPP.group.removeParticipants(${groupId.groupParse}, $parseList);''',
      methodName: "removeParticipants",
    );
  }

  /// Assign admins to a group
  Future promoteParticipants({
    required String groupId,
    required List<String> phoneNumbers,
  }) async {
    final parseList = jsonEncode(phoneNumbers.map(parsePhone).toList());
    return await wpClient.evaluateJs(
      '''window.WPP.group.promoteParticipants(${groupId.groupParse}, $parseList);''',
      methodName: "promoteParticipants",
    );
  }

  /// Remove admins from a group
  Future demoteParticipants({
    required String groupId,
    required List<String> phoneNumbers,
  }) async {
    final parseList = jsonEncode(phoneNumbers.map(parsePhone).toList());
    return await wpClient.evaluateJs(
      '''window.WPP.group.demoteParticipants(${groupId.groupParse}, $parseList);''',
      methodName: "demoteParticipants",
    );
  }

  /// Leave a group
  Future leave({required String groupId}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.group.leave(${groupId.groupParse});''',
      methodName: "leave",
    );
  }
}
