import 'package:drago_whatsapp_flutter/src/helper/utils.dart';

class MessageButtons {
  String text;
  String buttonData;
  ButtonType buttonType;

  MessageButtons({
    required this.text,
    required this.buttonData,
    required this.buttonType,
  });

  Map<String, dynamic> toJson() {
    return {
      "text".jsParse: text.jsParse,
      buttonType.name.jsParse: buttonData.jsParse,
    };
  }
}

enum ButtonType { id, url, phoneNumber }
