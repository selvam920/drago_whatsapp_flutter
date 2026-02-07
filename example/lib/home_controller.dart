// ignore_for_file: unnecessary_overrides, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drago_whatsapp_flutter/drago_whatsapp_flutter.dart';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class HomeController extends GetxController {
  var formKey = GlobalKey<FormState>();

  var message = TextEditingController();
  var phoneNumber = TextEditingController();
  var browserClientWebSocketUrl = TextEditingController();
  String? get browserEndPoint => browserClientWebSocketUrl.text.isNotEmpty
      ? browserClientWebSocketUrl.text
      : null;

  /// reactive variables from Getx
  RxString error = "".obs;
  RxBool connected = false.obs;
  RxBool connecting = false.obs;
  RxBool inApp = false.obs;
  Rx<ConnectionEvent?> connectionEvent = Rxn<ConnectionEvent>();
  Rx<Message?> messageEvents = Rxn<Message>();
  Rx<CallEvent?> callEvents = Rxn<CallEvent>();
  RxList<String> logs = <String>[].obs;
  RxString wppVersion = "latest".obs;

  RxList<String> availableVersions = <String>["latest"].obs;

  Rx<Duration> connectedDuration = Duration.zero.obs;
  Timer? _durationTimer;

  String get formatedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(connectedDuration.value.inMinutes.remainder(60));
    String seconds = twoDigits(connectedDuration.value.inSeconds.remainder(60));
    if (connectedDuration.value.inHours > 0) {
      return "${twoDigits(connectedDuration.value.inHours)}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  // Get whatsapp client first to perform other Tasks
  WhatsappClient? client;

  @override
  void onInit() {
    WhatsappBotUtils.enableLogs(true);
    _fetchWppVersions();
    WhatsappLogger.handleLogs = (log) {
      logs.add(log.toString());
      if (logs.length > 100) logs.removeAt(0);
      if (GetPlatform.isWeb || kDebugMode) {
        print(log.toString());
      }
    };
    message.text = "Testing Whatsapp Bot";
    super.onInit();
  }

  @override
  void onClose() {
    _stopDurationTimer();
    super.onClose();
  }

  Future<void> _fetchWppVersions() async {
    try {
      final response = await http.get(Uri.parse(
          "https://api.github.com/repos/wppconnect-team/wa-js/releases?per_page=10"));
      if (response.statusCode == 200) {
        final List releases = jsonDecode(response.body);
        final versions = releases.map((r) => r['tag_name'].toString()).toList();
        availableVersions.addAll(versions);
      }
    } catch (e) {
      WhatsappLogger.log("Error fetching versions: $e");
    }
  }

  void getAllGroups() => client?.group.getAllGroups();
  void getChats() => client?.chat.getChats();

  void initConnection(
      {bool inAppBrowser = false, InAppWebViewController? controller}) async {
    if (connecting.value || connected.value) return;
    connecting.value = true;
    error.value = "";
    String? version = wppVersion.value == "latest" ? null : wppVersion.value;
    try {
      if (inAppBrowser) {
        client = await DragoWhatsappFlutter.connectWithInAppBrowser(
          controller: controller!,
          onConnectionEvent: _onConnectionEvent,
          wppVersion: version,
        );
      } else {
        client = await DragoWhatsappFlutter.connect(
          saveSession: true,
          onConnectionEvent: _onConnectionEvent,
          onQrCode: _onQrCode,
          wppVersion: version,
        );
      }

      if (client != null) {
        connected.value = true;
        initListeners(client!);
      }
    } catch (er) {
      error.value = er.toString();
    } finally {
      connecting.value = false;
    }
  }

  void _onConnectionEvent(ConnectionEvent event) {
    connectionEvent(event);
    if (event == ConnectionEvent.connected) {
      _closeQrCodeDialog();
      _startDurationTimer();
    } else if (event == ConnectionEvent.logout ||
        event == ConnectionEvent.waitingForQrScan) {
      _stopDurationTimer();
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    connectedDuration.value = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      connectedDuration.value += const Duration(seconds: 1);
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    connectedDuration.value = Duration.zero;
  }

  void _onQrCode(String qrCodeUrl, Uint8List? imageBytes) {
    if (imageBytes != null) {
      _closeQrCodeDialog();
      _showQrCodeDialog(imageBytes);
    }
  }

  void _closeQrCodeDialog() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  void _showQrCodeDialog(Uint8List bytes) {
    Get.defaultDialog(
      title: "Scan QrCode",
      content: Image.memory(bytes),
      onCancel: () {},
    );
  }

  void initListeners(WhatsappClient client) async {
    // listen to ConnectionEvent Stream
    client.connectionEventStream.listen((event) {
      connectionEvent.value = event;
    });

    // listen to MessageEvents
    client.on(WhatsappEvent.chatnewmessage, (data) {
      List<Message> messages = Message.parse(data);
      if (messages.isEmpty) return;
      Message message = messages.first;
      Get.log(message.toJson().toString());
      if (!(message.id?.fromMe ?? true)) {
        messageEvents.value = message;
        // auto reply if message == test
        if (message.body == "test") {
          client.chat.sendTextMessage(
            phone: message.from,
            message: "Hey !",
            replyMessageId: message.id,
          );
        }
      }
    });

    // listen to CallEvents
    client.on(WhatsappEvent.incomingCall, (data) {
      List<CallEvent> events = CallEvent.parse(data);
      if (events.isEmpty) return;
      CallEvent event = events.first;
      callEvents.value = event;
      client.chat.rejectCall(callId: event.id);
      client.chat.sendTextMessage(
        phone: event.sender,
        message: "Hey, Call rejected by whatsapp bot",
      );
    });

    client.on(WhatsappEvent.chatmsgrevoke, (data) {
      Get.log("Revoking Event : $data");
    });
  }

  Future<void> disconnect() async {
    await client?.disconnect(tryLogout: true);
    connected.value = false;
    _stopDurationTimer();
  }

  Future<void> clearSession() async {
    await client?.clearSession(tryLogout: true);
    connected.value = false;
    _stopDurationTimer();
  }

  Future<void> sendMessage() async {
    if (!formKey.currentState!.validate()) return;
    try {
      final result = await client?.chat.sendTextMessage(
        phone: phoneNumber.text,
        message: message.text,
      );
      Get.log("Send Result: $result");
    } catch (e) {
      Get.log("Error : $e");
    }
  }

  Future<void> editLastMessage() async {
    if (messageEvents.value?.id == null) {
      Get.snackbar("Error", "No message to edit");
      return;
    }
    try {
      await client?.chat.editMessage(
        messageId: messageEvents.value!.id!,
        newMessage: "${message.text} (Edited)",
      );
      Get.snackbar("Success", "Message edited");
    } catch (e) {
      Get.log("Error : $e");
    }
  }

  Future<void> pinLastMessage() async {
    if (messageEvents.value?.id == null) {
      Get.snackbar("Error", "No message to pin");
      return;
    }
    try {
      await client?.chat.pinMessage(messageId: messageEvents.value!.id!);
      Get.snackbar("Success", "Message pinned for 24h");
    } catch (e) {
      Get.log("Error : $e");
    }
  }

  Future<void> postStatus() async {
    try {
      await client?.status.sendTextStatus(
        status: message.text,
        backgroundColor: "#075E54",
      );
      Get.snackbar("Success", "Status updated");
    } catch (e) {
      Get.log("Error : $e");
    }
  }

  Future<void> listLabels() async {
    try {
      final labels = await client?.labels.getAllLabels();
      Get.dialog(AlertDialog(
        title: const Text("Business Labels"),
        content: Text(labels.toString()),
      ));
    } catch (e) {
      Get.log("Error : $e");
    }
  }

  Future<void> sendButtonMessage() async {
    if (!formKey.currentState!.validate()) return;
    try {
      await client?.chat.sendTextMessage(
        phone: phoneNumber.text,
        message: message.text,
        useTemplate: true,
        templateTitle: "test title",
        templateFooter: "Footer",
        buttons: [
          MessageButtons(
            text: "Phone number",
            buttonData: "some phone number",
            buttonType: ButtonType.phoneNumber,
          ),
          MessageButtons(
            text: "open url",
            buttonData: "https://google.com/",
            buttonType: ButtonType.url,
          ),
          MessageButtons(
            text: "Button 1",
            buttonData: "some button id",
            buttonType: ButtonType.id,
          ),
          MessageButtons(
            text: "Button 2",
            buttonData: "some button id",
            buttonType: ButtonType.id,
          ),
          MessageButtons(
            text: "Button 3",
            buttonData: "some button id",
            buttonType: ButtonType.id,
          ),
        ],
      );
    } catch (e) {
      Get.log("Error : $e");
    }
  }

  Future<void> _sendFileMessage(
    String? filePath,
    String? fileName,
    WhatsappFileType fileType,
  ) async {
    if (!formKey.currentState!.validate()) return;
    try {
      if (filePath == null) return;
      File file = File(filePath);
      List<int> imageBytes = file.readAsBytesSync();
      await client?.chat.sendFileMessage(
        phone: phoneNumber.text,
        fileBytes: imageBytes,
        caption: message.text,
        fileType: fileType,
        fileName: fileName,
      );
    } catch (e) {
      Get.log("Error : $e");
    }
  }

  void pickFileAndSend(WhatsappFileType whatsappFileType) async {
    FileType fileType = FileType.any;
    switch (whatsappFileType) {
      case WhatsappFileType.image:
        fileType = FileType.image;
        break;
      case WhatsappFileType.audio:
        fileType = FileType.audio;
        break;
      default:
        break;
    }
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: fileType);
    String? path = result?.files.first.path;
    String? name = result?.names.first;
    await _sendFileMessage(path, name, whatsappFileType);
  }
}
