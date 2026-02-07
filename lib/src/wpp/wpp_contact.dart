import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppContact {
  WpClientInterface wpClient;
  WppContact(this.wpClient);

  /// get ProfilePictureUrl of any Number
  Future getProfilePictureUrl({
    required String phone,
  }) async {
    return await wpClient.evaluateJs(
      '''window.WPP.contact.getProfilePictureUrl(${phone.phoneParse});''',
      methodName: "getProfilePictureUrl",
    );
  }

  /// Get the current text status of contact
  Future getStatus({
    required String phone,
  }) async {
    return await wpClient.evaluateJs(
      '''window.WPP.contact.getStatus(${phone.phoneParse});''',
      methodName: "getStatus",
    );
  }

  /// Return to list of contacts
  Future getContacts() async {
    return await wpClient.evaluateJs(
      '''window.WPP.contact.list();''',
      methodName: "getContacts",
      forceJsonParseResult: true,
    );
  }
}
