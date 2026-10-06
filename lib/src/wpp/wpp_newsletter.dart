import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

/// WhatsApp Channels (wa-js calls them newsletters).
///
/// To post to a channel, pass its [WhatsappChatSummary.id] (`...@newsletter`)
/// as the `phone` of `chat.sendTextMessage` / `chat.sendFileMessage`. Only the
/// channel's owner and admins can post.
class WppNewsletter {
  WpClientInterface wpClient;
  WppNewsletter(this.wpClient);

  /// Channels this account owns, administers or follows.
  Future<List<WhatsappChatSummary>> list() async {
    final result = await wpClient.evaluateJs(
      '''(async function() {
        var chats = await window.WPP.chat.list({onlyNewsletter: true});
        return chats.map(function(c) {
          var meta = c.newsletterMetadata || {};
          var role = meta.membershipType || c.membershipType || c.role || null;
          var count = meta.subscribersCount != null ? meta.subscribersCount : (c.subscribersCount != null ? c.subscribersCount : null);
          return {
            id: c.id && c.id._serialized ? c.id._serialized : String(c.id),
            name: c.name || meta.name || c.formattedTitle || '',
            role: role ? String(role).toLowerCase() : null,
            memberCount: count
          };
        });
      })()''',
      methodName: "newsletterList",
    );
    return WhatsappChatSummary.parseList(result);
  }
}
