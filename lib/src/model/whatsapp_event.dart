/// Whatsapp Events, https://wppconnect.io/wa-js/modules/ev.html
/// Add more events if needed from the above link
///
/// use WhatsappClient.on(eventName,(data){}) to listen to events and client.off(eventName) to stop listening
///
///
class WhatsappEvent {
  // BlocklistEventTypes
  static String blocklistSync = 'blocklist.sync';

  // CallEventTypes
  static String incomingCall = 'call.incoming_call';

  // ChatEventTypes
  static String chatActiveChat = 'chat.active_chat';
  static String chatLiveLocationEnd = 'chat.live_location_end';
  static String chatLiveLocationStart = 'chat.live_location_start';
  static String chatLiveLocationUpdate = 'chat.live_location_update';
  static String chatmsgackchange = 'chat.msg_ack_change';
  static String chatmsgrevoke = 'chat.msg_revoke';
  static String chatnewmessage = 'chat.new_message';
  static String chatnewreaction = 'chat.new_reaction';
  static String chatpollresponse = 'chat.poll_response';
  static String chatpresencechange = 'chat.presence_change';
  static String chatupdatelabel = 'chat.update_label';

  // ConfigEventTypes
  static String configupdate = 'config.update';

  // ConnEventTypes
  static String connauthcodechange = 'conn.auth_code_change';
  static String connauthenticated = 'conn.authenticated';
  static String connlogout = 'conn.logout';
  static String connmaininit = 'conn.main_init';
  static String connmainloaded = 'conn.main_loaded';
  static String connmainready = 'conn.main_ready';
  static String connneedsupdate = 'conn.needs_update';
  static String connonline = 'conn.online';
  static String connqrcodeidle = 'conn.qrcode_idle';
  static String connrequireauth = 'conn.require_auth';

  // GroupEventTypes
  static String groupparticipantchanged = 'group.participant_changed';

  // StatusEventTypes
  static String statussync = 'status.sync';

  // WebpackEvents
  static String webpackinjected = 'webpack.injected';
  static String webpackready = 'webpack.ready';
}
