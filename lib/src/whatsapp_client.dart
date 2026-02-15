import 'dart:async';

import 'package:drago_whatsapp_flutter/drago_whatsapp_flutter.dart';
import 'package:drago_whatsapp_flutter/src/wpp/wpp_conn.dart';
import 'package:drago_whatsapp_flutter/src/wpp/wpp_group.dart';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

/// get [WhatsappClient] from `WhatsappBotFlutter.connect()`
/// please do not try to create on your own
class WhatsappClient {
  final WpClientInterface wpClient;

  // Wpp Classes
  late final WppChat chat;
  late final WppContact contact;
  late final WppProfile profile;
  late final WppGroup group;
  late final WppConn conn;
  late final WppStatus status;
  late final WppLabels labels;
  late final WppEvents _wppEvents;
  late final WppAuth _wppAuth;

  WhatsappClient({required this.wpClient}) {
    chat = WppChat(wpClient);
    contact = WppContact(wpClient);
    profile = WppProfile(wpClient);
    group = WppGroup(wpClient);
    conn = WppConn(wpClient);
    status = WppStatus(wpClient);
    labels = WppLabels(wpClient);
    _wppAuth = WppAuth(wpClient);
    _wppEvents = WppEvents(wpClient);
    _wppEvents.init();
  }

  /// To list to any event from WPP
  /// Get event name from [WhatsappEvent]
  Future<void> on(String event, Function(dynamic) callback) =>
      wpClient.on(event, callback);

  /// To remove listener from any event from WPP
  Future<void> off(String event) => wpClient.off(event);

  /// To run a custom function on WPP
  Future executeFunction(
    String function, {
    bool tryPromise = true,
  }) async {
    await wpClient.evaluateJs(
      function,
      methodName: "executeFunction",
      tryPromise: tryPromise,
    );
  }

  /// [isConnected] is to check if we are still connected to the WhatsappPage
  bool get isConnected => wpClient.isConnected();

  /// [isAuthenticated] is to check if we are loggedIn
  Future<bool> get isAuthenticated => _wppAuth.isAuthenticated();

  /// [isReadyToChat] is to check if whatsapp chat Page opened
  Future<bool> get isReadyToChat => _wppAuth.isMainReady();

  /// [connectionEventStream] will give update of Connection Events
  Stream<ConnectionEvent> get connectionEventStream =>
      _wppEvents.connectionEventStreamController.stream;

  /// [disconnect] will close the browser instance and set values to null
  Future<void> disconnect({
    bool tryLogout = false,
  }) async {
    try {
      if (tryLogout) await logout();
      await wpClient.dispose();
    } catch (e) {
      WhatsappLogger.log(e);
    }
  }

  /// [clearSession] will logout, disconnect and delete the session data
  Future<void> clearSession({
    bool tryLogout = true,
  }) async {
    try {
      String? sessionPath = wpClient.sessionPath;
      await disconnect(tryLogout: tryLogout);
      await DragoWhatsappFlutter.clearSession(sessionPath: sessionPath);
    } catch (e) {
      WhatsappLogger.log(e);
    }
  }

  ///[logout] will try to logout only if We are connected and already logged in
  Future<void> logout() async {
    try {
      if (isConnected && await _wppAuth.isAuthenticated()) {
        await _wppAuth.logout();

        // Wait for logout state to be reflected
        int attempts = 0;
        while (attempts < 5 && isConnected) {
          if (!(await _wppAuth.isAuthenticated())) break;
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }
      }
    } catch (e) {
      WhatsappLogger.log(e);
    }
  }
}
