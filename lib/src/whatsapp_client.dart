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

  /// connect() only builds the client once logged in, so it starts linked:
  /// a "not logged in" on the first tick is an unlink, not QR pairing.
  bool _wasLinked = true;

  /// [ConnectionEvent.disconnected] was reported and not yet undone.
  bool _offlineReported = false;

  /// Checks in a row that got no answer from the page.
  int _failedChecks = 0;

  /// After this many unanswered checks the browser counts as dead.
  static const int maxFailedChecks = 3;

  /// WhatsApp can unlink this device at any time (phone offline ~14 days,
  /// removed under Linked devices, a security check), and WhatsApp Web
  /// reloads its page when it updates. Either one used to go unseen until a
  /// send failed: a reload drops wa-js and every listener, and a logout then
  /// raises no event at all. So the link is checked here: wa-js is put back
  /// when gone, and a logout is reported once as [ConnectionEvent.logout].
  /// A lost connection (no internet, phone unreachable) is reported once as
  /// [ConnectionEvent.disconnected], and its return as
  /// [ConnectionEvent.connected], so apps queue sends meanwhile.
  ///
  /// The browser itself can die too (Android kills the renderer, Windows
  /// sleep takes WebView2 down): the page then stops answering, or the
  /// WebView stops running. That is reported as
  /// [ConnectionEvent.disconnected] as well -- straight away when the
  /// WebView is gone, after [maxFailedChecks] unanswered checks otherwise --
  /// so the app can restart the browser instead of waiting forever.
  Future<void> _checkLink() async {
    if (_checking || _watchdog == null) return;
    _checking = true;
    try {
      if (!isConnected) {
        _reportDown('browser not running');
        return;
      }
      var state = await WppConnect.linkState(wpClient)
          .timeout(_evalTimeout, onTimeout: () => WppLinkState.gone);
      if (_watchdog == null) return;
      if (state == WppLinkState.gone && isConnected) {
        try {
          await WppConnect.ensureReady(wpClient)
              .timeout(const Duration(seconds: 90));
        } catch (_) {
          // ensureReady reports a logout itself; anything else is retried
          // on the next tick.
        }
        if (_watchdog == null) return;
        state = await WppConnect.linkState(wpClient)
            .timeout(_evalTimeout, onTimeout: () => WppLinkState.gone);
      }
      if (_watchdog == null) return;
      if (state == WppLinkState.gone) {
        _failedChecks++;
        WhatsappLogger.log(
            "link check: no answer from the page ($_failedChecks/$maxFailedChecks)");
        if (!isConnected) {
          _reportDown('browser not running');
        } else if (_failedChecks >= maxFailedChecks) {
          _reportDown('page not answering');
        }
        return;
      }
      _failedChecks = 0;
      if (state == WppLinkState.loggedOut && _wasLinked) {
        // Deduped in reportLogout, together with ensureReady's own report.
        await WppConnect.reportLogout(wpClient);
      } else if (state == WppLinkState.offline) {
        _reportDown('WhatsApp offline');
      } else if (state == WppLinkState.linked) {
        _wasLinked = true;
        WppConnect.markLinked(wpClient);
        if (_offlineReported) {
          _offlineReported = false;
          _emit(ConnectionEvent.connected);
        }
      }
    } catch (e) {
      WhatsappLogger.log("link check failed: $e");
    } finally {
      _checking = false;
    }
  }

  static const Duration _evalTimeout = Duration(seconds: 20);

  /// Reports [ConnectionEvent.disconnected] once until the link is back.
  /// Straight into the stream: a dead page could not pass it on.
  void _reportDown(String why) {
    if (_offlineReported) return;
    _offlineReported = true;
    WhatsappLogger.log("WhatsApp disconnected: $why");
    _emit(ConnectionEvent.disconnected);
  }

  void _emit(ConnectionEvent event) {
    final controller = _wppEvents.connectionEventStreamController;
    if (!controller.isClosed) controller.add(event);
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
    } catch (e) {
      WhatsappLogger.log(e);
    }
    try {
      await wpClient.dispose();
    } catch (e) {
      WhatsappLogger.log(e);
    }
    // Its own try: a WebView that fails to dispose must not leave the event
    // streams open.
    try {
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
