import 'dart:async';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppEvents {
  WpClientInterface wpClient;
  WppEvents(this.wpClient);

  // To get update of all Connections
  final StreamController<ConnectionEvent> connectionEventStreamController =
      StreamController.broadcast();

  /// call init() once on a page
  /// to add eventListeners
  Future<void> init() async {
    await wpClient.initializeEventListener(_onNewEvent);
  }

  void _onNewEvent(String eventName, dynamic eventData) {
    switch (eventName) {
      case "connectionEvent":
        _onConnectionEvent(eventData);
        break;
    }
  }

  void _onConnectionEvent(dynamic event) {
    ConnectionEvent? connectionEvent;

    // Check if it's already a ConnectionEvent name (from manual emission)
    for (var value in ConnectionEvent.values) {
      if (value.name == event) {
        connectionEvent = value;
        break;
      }
    }

    if (connectionEvent == null) {
      if (event == WhatsappEvent.connauthenticated) {
        connectionEvent = ConnectionEvent.authenticated;
      } else if (event == WhatsappEvent.connlogout) {
        connectionEvent = ConnectionEvent.logout;
      } else if (event == WhatsappEvent.connauthcodechange) {
        connectionEvent = ConnectionEvent.authCodeChange;
      } else if (event == WhatsappEvent.connmainloaded) {
        connectionEvent = ConnectionEvent.connecting;
      } else if (event == WhatsappEvent.connmainready) {
        connectionEvent = ConnectionEvent.connected;
      } else if (event == WhatsappEvent.connrequireauth) {
        connectionEvent = ConnectionEvent.requireAuth;
      } else {
        // Fallback for suffixes or other strings
        switch (event) {
          case "authenticated":
            connectionEvent = ConnectionEvent.authenticated;
            break;
          case "logout":
            connectionEvent = ConnectionEvent.logout;
            break;
          case "auth_code_change":
            connectionEvent = ConnectionEvent.authCodeChange;
            break;
          case "main_loaded":
            connectionEvent = ConnectionEvent.connecting;
            break;
          case "main_ready":
            connectionEvent = ConnectionEvent.connected;
            break;
          case "require_auth":
            connectionEvent = ConnectionEvent.requireAuth;
            break;
          case "disconnected":
            connectionEvent = ConnectionEvent.disconnected;
            break;
          case "connected":
            connectionEvent = ConnectionEvent.connected;
            break;
          default:
            WhatsappLogger.log("Unknown Event : $event");
        }
      }
    }

    if (connectionEvent == null) return;
    connectionEventStreamController.add(connectionEvent);
  }
}
