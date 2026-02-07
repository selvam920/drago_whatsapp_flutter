# WhatsApp Bot Dashboard Example

This example demonstrates the full capabilities of `drago_whatsapp_flutter`, featuring a professional dashboard to manage your WhatsApp bot.

## Features in this Example:

- 📊 **Real-time Console**: Dedicated sidebar for system logs and debug information.
- ⏱️ **Connection Tracker**: Live timer showing session duration and connectivity health.
- 🚀 **Multi-Mode Connection**: Toggle between Headless (Background) and Visual (InApp) browsers.
- 📸 **Live Snapshots**: Take screenshots of the background headless browser for debugging.
- ✉️ **Message Builder**: Interface to test sending Text, Media, and Template buttons.
- 🔔 **Event Stream**: Visual representation of incoming messages and calls.

## Getting Started

1.  **Dependencies**: Ensure you have Flutter installed.
2.  **Run the app**:
    ```bash
    flutter run
    ```
3.  **Connect**: Click on "Instant Connect" for a headless session or "Visual Browser" to see the login QR code directly.

## Platform Notes

- **Desktop (Windows/macOS)**: Recommended for bot development as it provides stable Webview support.
- **Mobile (Android/iOS)**: Fully supported; ensures you use a valid Desktop User Agent (handled automatically by the plugin).

## Testing Scenarios

- **Auto-Reply**: Send "test" to the bot's number from another device; it will reply "Hey !".
- **Call Rejection**: Incoming calls are automatically rejected by the bot logic in `HomeController`.
- **Media**: Test the "Image" or "Document" buttons to pick files from your device and send them.

