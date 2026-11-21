import 'dart:async';

import 'package:drago_whatsapp_flutter/drago_whatsapp_flutter.dart';
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
  late final WppNewsletter newsletter;
  late final WppEvents _wppEvents;
  late final WppAuth _wppAuth;

  WhatsappClient({
    required this.wpClient,
    WppEvents? wppEvents,
  }) {
    chat = WppChat(wpClient);
    contact = WppContact(wpClient);
    profile = WppProfile(wpClient);
    group = WppGroup(wpClient);
    conn = WppConn(wpClient);
    status = WppStatus(wpClient);
    labels = WppLabels(wpClient);
    newsletter = WppNewsletter(wpClient);
    _wppAuth = WppAuth(wpClient);
    _wppEvents = wppEvents ?? WppEvents(wpClient);
    if (wppEvents == null) {
      _wppEvents.init().catchError((Object e) {
        WhatsappLogger.log("WppEvents init failed: $e");
      });
    }
    _watchdog = Timer.periodic(watchInterval, (_) => _checkLink());
  }

  /// How often the link is checked while the bot runs.
  static const Duration watchInterval = Duration(seconds: 45);

  Timer? _watchdog;
  bool _checking = false;
  bool _loggedOutReported = false;

  /// Seen linked at least once: before that, "not logged in" is first-time
  /// pairing (QR on screen), not a logout.
  bool _wasLinked = false;

  /// WhatsApp can unlink this device at any time (phone offline ~14 days,
  /// removed under Linked devices, a security check), and WhatsApp Web
  /// reloads its page when it updates. Either one used to go unseen until a
  /// send failed: a reload drops wa-js and every listener, and a logout then
  /// raises no event at all. So the link is checked here: wa-js is put back
  /// when gone, and a logout is reported once as [ConnectionEvent.logout].
  Future<void> _checkLink() async {
    if (_checking || !isConnected) return;
    _checking = true;
    try {
      var state = await WppConnect.linkState(wpClient);
      if (state == WppLinkState.gone) {
        try {
          await WppConnect.ensureReady(wpClient);
        } catch (_) {
          // ensureReady reports a logout itself; anything else is retried
          // on the next tick.
        }
        state = await WppConnect.linkState(wpClient);
      }
      if (state == WppLinkState.loggedOut &&
          _wasLinked &&
          !_loggedOutReported) {
        _loggedOutReported = true;
        await WppConnect.reportLogout(wpClient);
      } else if (state == WppLinkState.linked) {
        _wasLinked = true;
        _loggedOutReported = false;
      }
    } catch (e) {
      WhatsappLogger.log("link check failed: $e");
    } finally {
      _checking = false;
    }
  }

  /// To list to any event from WPP
  /// Get event name from [WhatsappEvent]
  Future<void> on(String event, Function(dynamic) callback) =>
      wpClient.on(event, callback);

  /// To remove a listener added with [on]; without [callback], every
  /// listener this client added for [event]
  Future<void> off(String event, [Function(dynamic)? callback]) =>
      wpClient.off(event, callback);

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

  /// [qrCodeStream] will give update of QrCode
  Stream<QrCodeImage> get qrCodeStream =>
      _wppEvents.qrCodeStreamController.stream;

  /// [disconnect] will close the browser instance and set values to null
  Future<void> disconnect({
    bool tryLogout = false,
  }) async {
    _watchdog?.cancel();
    _watchdog = null;
    try {
      if (tryLogout) await logout();
      await wpClient.dispose();
      await _wppEvents.dispose();
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
