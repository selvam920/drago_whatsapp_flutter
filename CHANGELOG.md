## 0.0.1

* initial release.

## 0.0.2

* Windows webview path changes.

## 0.0.3

* Windows webview path changes in inappview.

## 0.0.4

* Removed Windows webview path changes in this package.

## 0.0.6

* Added session directory path

## 0.0.7

* use wpp connect specific version

## 0.0.8

* added clear session method.

## 0.0.9

* fixed clear cache issue.

## 0.1.0

* improve the connectivity.

## 0.1.1

* **Performance**: Implemented "Fast Connect" logic with optimized script injection and module loading.
* **UX**: Complete revamp of the example app with a modern dashboard, live console, and state tracking.
* **Fixes**: Optimized initialization sequence and improved error handling for headless browsers.
* **Docs**: Comprehensive update to README.md and example documentation.

## 0.1.2

* Fix whatsapp connectivity issue

## 0.1.3

* Fix windows sesstion path

## 0.1.4

* skip Qr scan improvement

## 0.1.5

* return proper events. 

## 0.1.6

* improved whatsapp connectivity. 

## 0.1.7

* improved windows file send. 

## 0.1.8

* Ignore continously hit whatsapp when no login.

## 0.1.9

- Bug fix

## 0.2.0

- Migrated with material ui package

## 0.2.1

- Migrated Android AGP

## 0.3.0

- **Breaking:** no global `HttpOverrides` by default (`enableHttpOverrides` is deprecated and `false`); the headless WebView no longer accepts invalid certificates.
- **Breaking:** `WpClientInterface.off(event, [callback])` removes only this client's listener, and `restoreListeners()` was added. Several callbacks may share one event.
- `Message.ack` / `isSent` / `isFailed` and `MessageAck`; `chat.getMessageAck`.
- Groups and channels: `group.list()`, `newsletter.list()`, `WhatsappChatSummary`; send methods accept a full chat id (`@g.us`, `@newsletter`).
- `chat.sendCatalogMessage` for the WhatsApp Business catalog.
- JS arguments are JSON-encoded (quotes, backslashes and lists in messages no longer break the script); phone numbers lose spaces and dashes.
- wa-js pinned to `WppConnect.defaultWppVersion` with fallback to latest; `wppJsContent` to ship the script; `autoTakeover` option.
- `isValidContact` returns the real result; file sends are queued and match only their own message; no file-name caption on images; status images keep their real MIME type.
- Connection wait no longer overlaps checks, and re-injects WPP with the same version/config after its recovery reload.
- Headless and embedded clients share one base class; event streams close on disconnect.
