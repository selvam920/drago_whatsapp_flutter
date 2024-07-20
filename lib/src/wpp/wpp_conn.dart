import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppConn {
  WpClientInterface wpClient;
  WppConn(this.wpClient);

  /// Set keep alive state, that will force the focused and online state
  Future setAlive([bool value = true]) async {
    var aliveValue = value ? '' : false;
    return await wpClient.evaluateJs(
      '''WPP.conn.setKeepAlive($aliveValue);''',
      methodName: "setAlive",
    );
  }

  /// Check if whatsapp web is asking for update
  Future needsUpdate() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.needsUpdate();''',
      methodName: "needsUpdate",
    );
  }

  /// Check is online
  Future isOnline() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.isOnline();''',
      methodName: "isOnline",
    );
  }

  /// Return the current logged user ID with device id
  Future getMyDeviceId() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.getMyDeviceId();''',
      methodName: "getMyDeviceId",
    );
  }

  /// Return the current logged user ID without device id
  Future getMyUserId() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.getMyUserId();''',
      methodName: "getMyUserId",
    );
  }

  /// Set the online state to online
  Future markAvailable() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.markAvailable();''',
      methodName: "markAvailable",
    );
  }

  /// Check is the current browser is logged before loading
  Future isRegistered() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.isRegistered();''',
      methodName: "isRegistered",
    );
  }

  /// Check if multiDevice
  Future isMultiDevice() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.isMultiDevice();''',
      methodName: "isMultiDevice",
    );
  }

  /// If it's true, WhatsApp WEB will switch to MD. If it's false, WhatsApp WEB will switch to Legacy.
  Future setMultiDevice(bool value) async {
    return await wpClient.evaluateJs(
      '''WPP.conn.setMultiDevice($value);''',
      methodName: "setMultiDevice",
    );
  }

  /// To get auth Code
  Future getAuthCode() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.getAuthCode();''',
      methodName: "getAuthCode",
    );
  }

  /// Check if idle
  Future isIdle() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.isIdle();''',
      methodName: "isIdle",
    );
  }

  /// Check if main is initialized
  Future isMainInit() async {
    return await wpClient.evaluateJs(
      '''WPP.conn.isMainInit();''',
      methodName: "isMainInit",
    );
  }
}
