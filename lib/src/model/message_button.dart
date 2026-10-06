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
      "text": text,
      buttonType.name: buttonData,
    };
  }
}

enum ButtonType { id, url, phoneNumber }
