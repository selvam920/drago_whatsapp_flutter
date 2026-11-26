// ignore_for_file: empty_catches

import 'dart:async';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

/// What the WhatsApp Web page shows while a new login is paired, read in
/// one call.
class LoginPageState {
  const LoginPageState({
    this.wpp = false,
    this.loading = false,
    this.qr = false,
    this.authenticated = false,
    this.registered = false,
    this.streamMode,
    this.streamInfo,
  });

  /// wa-js is on the page. WhatsApp Web reloads its page right after a scan,
  /// which drops it.
  final bool wpp;

  /// The page itself is still loading.
  final bool loading;

  /// A QR code is on screen.
  final bool qr;
  final bool authenticated;
  final bool registered;

  /// `WPP.conn.getStreamData()`: mode QR / SYNCING / MAIN, info OPENING /
  /// PAIRING / SYNCING / NORMAL ...
  final String? streamMode;
  final String? streamInfo;

  /// The phone scanned the QR. Authenticated is certain; the other signals
  /// count only once a QR was on screen and is gone again: WhatsApp then
  /// pairs and loads the chats, which can take minutes on a new login.
  bool scanned({required bool qrShown}) {
    if (authenticated) return true;
    if (!wpp || !qrShown || qr) return false;
    return registered ||
        streamMode == 'SYNCING' ||
        streamMode == 'MAIN' ||
        streamInfo == 'SYNCING';
  }

  /// Back on the QR screen and not linked: a lost link, not a slow load.
  bool get showsQr => wpp && qr && !authenticated && !registered;

  static Future<LoginPageState> read(WpClientInterface wpClient) async {
    try {
      final r = await wpClient.evaluateJs(
        '''(function() {
          var r = {wpp: false, loading: document.readyState !== 'complete',
                   qr: false, auth: false, reg: false, mode: null, info: null};
          try {
            var c = document.querySelector('canvas');
            r.qr = !!(c && c.closest('[data-ref]'));
          } catch (e) {}
          var W = window.WPP;
          if (typeof W === 'undefined' || !W || !W.conn) return r;
          r.wpp = true;
          try { r.auth = !!W.conn.isAuthenticated(); } catch (e) {}
          try {
            if (typeof W.conn.isRegistered === 'function') r.reg = !!W.conn.isRegistered();
          } catch (e) {}
          try {
            if (typeof W.conn.getStreamData === 'function') {
              var s = W.conn.getStreamData();
              if (s && s.mode) r.mode = String(s.mode);
              if (s && s.info) r.info = String(s.info);
            }
          } catch (e) {}
          return r;
        })()''',
        tryPromise: false,
      );
      if (r is! Map) return const LoginPageState(loading: true);
      bool flag(String key) => r[key] == true || r[key]?.toString() == 'true';
      return LoginPageState(
        wpp: flag('wpp'),
        loading: flag('loading'),
        qr: flag('qr'),
        authenticated: flag('auth'),
        registered: flag('reg'),
        streamMode: r['mode']?.toString(),
        streamInfo: r['info']?.toString(),
      );
    } catch (e) {
      // The page is between documents (reloading) or the WebView is busy.
      return const LoginPageState(loading: true);
    }
  }

  @override
  String toString() => 'wpp=$wpp loading=$loading qr=$qr auth=$authenticated '
      'reg=$registered mode=$streamMode info=$streamInfo';
}

/// Shows the QR the moment WhatsApp Web draws it, while wa-js is still
/// being injected and started -- that alone used to keep "Opening WhatsApp
/// Web..." up for many seconds after the code was already on the page. It
/// reads the page itself (no wa-js needed) and hands each new code to
/// [onQr]; [stop] ends it before the normal scan wait takes over with
/// [lastCode].
class EarlyQrWatcher {
  EarlyQrWatcher(this.wpClient, this.onQr);

  final WpClientInterface wpClient;
  final void Function(QrCodeImage qr) onQr;

  /// The last code shown, or null when none was.
  String? lastCode;
  bool _stopped = false;

  void start() => _run();

  void stop() => _stopped = true;

  Future<void> _run() async {
    while (!_stopped) {
      try {
        final r = await wpClient.evaluateJs(
          '''(function() {
            try {
              var c = document.querySelector('canvas');
              if (!c || c.width <= 1 || c.height <= 1) return null;
              var d = c.closest('[data-ref]');
              var ref = d ? d.getAttribute('data-ref') : null;
              if (!ref) return null;
              return {urlCode: ref, base64Image: c.toDataURL()};
            } catch (e) { return null; }
          })()''',
          tryPromise: false,
        );
        if (_stopped) return;
        if (r is Map) {
          final code = r['urlCode']?.toString();
          final image = r['base64Image']?.toString();
          if (code != null && image != null && code != lastCode) {
            lastCode = code;
            WhatsappLogger.log('QR code on the page (before wa-js is ready)');
            onQr(QrCodeImage(base64Image: image, urlCode: code));
          }
        }
      } catch (_) {
        // Page still loading or between documents; look again.
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }
}

/// Shows each new QR through [onCatchQR] until the phone scans it, and
/// returns as soon as the scan itself is seen -- not after the chats load.
///
/// [waitDurationSeconds] covers the QR only. A scan near the deadline is
/// never cut off: once the page leaves the QR screen (WhatsApp reloads it
/// after a scan) the wait runs on until the page says what happened.
/// When [isStopped] turns true (the login finished another way) the wait
/// returns without showing another QR. [shownQrCode] is a code the app
/// already shows (see [EarlyQrWatcher]); it is not shown twice.
Future<void> waitForQrCodeScan({
  required WpClientInterface wpClient,
  int waitDurationSeconds = 60,
  Function(QrCodeImage, int)? onCatchQR,
  bool Function()? isStopped,
  String? shownQrCode,
}) async {
  String? urlCode = shownQrCode;
  int attempt = shownQrCode == null ? 0 : 1;
  bool qrShown = shownQrCode != null;
  bool done = false;
  bool stopped() => done || (isStopped?.call() ?? false);
  final deadline = DateTime.now().add(Duration(seconds: waitDurationSeconds));
  // A page that left the QR screen gets this long past the deadline to come
  // back linked (or with a QR) before the wait gives up.
  final hardDeadline = deadline.add(const Duration(seconds: 60));

  void show(QrCodeImage result) {
    final code = result.urlCode;
    if (stopped() || code == null || code == urlCode) return;
    urlCode = code;
    qrShown = true;
    attempt++;
    WhatsappLogger.log('Waiting for QRCode Scan: Attempt $attempt');
    onCatchQR?.call(result, attempt);
  }

  // A listener for QR code change, to be more reactive than the poll.
  Future<void> onCodeChange(dynamic _) async {
    if (stopped()) return;
    final result = await wpClient.getQrCode();
    if (result != null) show(result);
  }

  try {
    await wpClient.on(WhatsappEvent.connauthcodechange, onCodeChange);
  } catch (e) {
    WhatsappLogger.log("Failed to set QR code change listener: $e");
  }

  DateTime? lastInject;
  bool suspect = false; // last poll looked like a scan, not yet certain

  try {
    while (!stopped()) {
      final state = await LoginPageState.read(wpClient);
      if (stopped()) return;

      if (state.scanned(qrShown: qrShown)) {
        // Authenticated is certain; the softer signals must hold twice.
        if (state.authenticated || suspect) {
          WhatsappLogger.log('QR code scanned ($state)');
          return;
        }
        suspect = true;
      } else {
        suspect = false;
      }

      if (!state.wpp && !state.loading) {
        // WhatsApp Web reloaded its page -- it does right after a scan --
        // and wa-js went with it. Put it back so the scan can be seen.
        final now = DateTime.now();
        if (lastInject == null || now.difference(lastInject).inSeconds >= 5) {
          lastInject = now;
          WhatsappLogger.log('WPP gone while waiting for the scan, '
              'injecting again');
          try {
            await WppConnect.ensureInjected(wpClient);
          } catch (e) {
            WhatsappLogger.log('Re-inject during login failed: $e');
          }
          continue;
        }
      }

      if (state.qr) {
        final result = await wpClient.getQrCode();
        if (result != null) show(result);
      }

      final now = DateTime.now();
      if (now.isAfter(deadline)) {
        // Still on the QR screen (or never got one): the QR expired. Any
        // other page -- reloading, pairing, loading chats -- gets until the
        // hard deadline to settle.
        final onQrScreen =
            state.wpp && !state.loading && !suspect && (state.qr || !qrShown);
        if (onQrScreen || now.isAfter(hardDeadline)) {
          // Last look before giving up: a scan in the final second counts.
          final last = await LoginPageState.read(wpClient);
          if (stopped() || last.scanned(qrShown: qrShown)) return;
          throw const WhatsappException(
            message: 'Timeout waiting for QR code scan',
            exceptionType: WhatsappExceptionType.timeout,
          );
        }
      }
      // Quick until the first code is up, then once a second.
      await Future.delayed(Duration(milliseconds: qrShown ? 1000 : 400));
    }
  } finally {
    done = true;
    try {
      await wpClient.off(WhatsappEvent.connauthcodechange, onCodeChange);
    } catch (e) {}
  }
}
