# drago_whatsapp_flutter

This plugin will allow to access whatsapp in the background to send text, files, etc.

## Getting Started

```
    flutter pub add drago_whatsapp_flutter

```

## Example of Usage

    WhatsappClient? client;
    client = await DragoWhatsappFlutter.connect(
          saveSession: true,
          onConnectionEvent: _onConnectionEvent,
          onQrCode: _onQrCode,
        );

    await client?.chat.sendTextMessage(
        phone: phoneNumber.text,
        message: message.text,
      );

### Clear Session

    await client?.clearSession(); // This will clear session files and cookies