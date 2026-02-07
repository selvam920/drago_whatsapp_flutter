# drago_whatsapp_flutter

A powerful Flutter plugin to automate WhatsApp Web interactions. Built on top of [wa-js (WPPConnect)](https://github.com/wppconnect-team/wa-js) and `flutter_inappwebview`, it allows you to send messages, media, manage groups, and listen to events either headlessly or through an interactive UI.

## Features

- 🚀 **Fast Connect**: Optimized initialization sequence and early script injection.
- 🎭 **Headless & Visual Modes**: Run in the background or embed WhatsApp Web in your UI.
- 📱 **Messaging**: Send text (edit/pin), images, videos, documents, and buttons/templates.
- 👥 **Group Management**: Fetch groups, manage participants (promote/demote), and more.
- 📉 **Status/Story**: Post text, image, and video updates to your status.
- 🏷️ **Labels**: Full support for WhatsApp Business labels (list/add/delete).
- 🔔 **Event Stream**: Real-time listeners for messages, calls, and connection states.
- 💾 **Session Management**: Persistent login support for seamless restarts.
- 🛠️ **Customizable**: Supply specific `wa-js` versions and configurations.

## Platform Support

| Android | iOS | Windows | macOS | Linux | Web |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  drago_whatsapp_flutter: ^0.1.0
```

or run:

```bash
flutter pub add drago_whatsapp_flutter
```

## Basic Usage

### Initialize Headless Connection

This is ideal for background bots.

```dart
WhatsappClient? client;

client = await DragoWhatsappFlutter.connect(
  saveSession: true,
  onConnectionEvent: (event) {
    print("Connection Event: ${event.name}");
  },
  onQrCode: (qrCodeUrl, imageBytes) {
    // Display QR Code to user
  },
);

if (client != null) {
  print("Connected successfully!");
}
```

### Send a Message

```dart
await client?.chat.sendTextMessage(
  phone: "1234567890", // With country code
  message: "Hello from Flutter!",
);
```

### Send Media/Buttons

```dart
// Send Image
await client?.chat.sendFileMessage(
  phone: "1234567890",
  fileBytes: imageBytes,
  fileType: WhatsappFileType.image,
  caption: "Check this out!",
);

// Send Buttons (Templates)
await client?.chat.sendTextMessage(
  phone: "1234567890",
  message: "Pick an option:",
  useTemplate: true,
  buttons: [
    MessageButtons(
      text: "Visit Google",
      buttonData: "https://google.com",
      buttonType: ButtonType.url,
    ),
  ],
);
```

### Listen to Incoming Messages

```dart
client?.on(WhatsappEvent.chatnewmessage, (data) {
  final List<Message> messages = Message.parse(data);
  for (var msg in messages) {
    print("New message from ${msg.from}: ${msg.body}");
  }
});
```

## Advanced Configuration

### Using specific wa-js version
You can specify a version from [wa-js releases](https://github.com/wppconnect-team/wa-js/releases).

```dart
client = await DragoWhatsappFlutter.connect(
  wppVersion: "1.30.0",
);
```

### Visual Browser Integration

If you want the user to see the WhatsApp Web interface (useful for debugging or first-time login):

```dart
// In your UI using flutter_inappwebview
InAppWebView(
  onLoadStop: (controller, url) async {
    client = await DragoWhatsappFlutter.connectWithInAppBrowser(
      controller: controller,
    );
  },
)
```

## Session Cleanup

To logout and clear all saved credentials:

```dart
await client?.clearSession(); 
```

## Credits

This package is built using:
- [WPPConnect wa-js](https://github.com/wppconnect-team/wa-js) for the WhatsApp Web bridge.
- [flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview) for the browser engine.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
