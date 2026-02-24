import 'dart:convert';
import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppChat {
  WpClientInterface wpClient;
  WppChat(this.wpClient);

  /// [sendMessage] may throw errors if passed an invalid contact
  /// returns [Message] object if sent successfully
  /// add `replyMessageId` to quote message
  Future<Message?> sendTextMessage({
    required String phone,
    required String message,
    String? templateTitle,
    String? templateFooter,
    bool useTemplate = false,
    List<MessageButtons>? buttons,
    MessageId? replyMessageId,
  }) async {
    String? replyText = replyMessageId?.serialized;
    String? buttonsText = buttons != null
        ? jsonEncode(buttons.map((e) => e.toJson()).toList())
        : null;
    var result = await wpClient.evaluateJs(
        '''window.WPP.chat.sendTextMessage(${phone.phoneParse}, ${message.jsParse}, {
            quotedMsg: ${replyText.jsParse},
            useTemplateButtons: ${useTemplate.jsParse},
            buttons:$buttonsText,
            title: ${templateTitle.jsParse},
            footer: ${templateFooter.jsParse}
          });''',
        methodName: "sendTextMessage");

    return Message.parse(result).firstOrNull;
  }

  ///send file messages using [sendFileMessage]
  /// returns [Message] object if sent successfully
  /// make sure to send fileType , we can also pass optional mimeType
  /// `replyMessageId` will send a quote message to the given messageId
  /// add `caption` to attach a text with the file
  ///
  /// On Windows WebView2, this method bypasses WPP.chat.sendFileMessage
  /// and uses low-level WPP internals because the high-level API has
  /// an internal Promise that hangs due to chat.msgs.on('add') never firing.
  Future<Message?> sendFileMessage({
    required String phone,
    required WhatsappFileType fileType,
    required List<int> fileBytes,
    String? fileName,
    String? caption,
    String? mimetype,
    MessageId? replyMessageId,
    String? templateTitle,
    String? templateFooter,
    bool useTemplate = false,
    bool isViewOnce = false,
    bool audioAsPtt = false,
    List<MessageButtons>? buttons,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    String base64Image = base64Encode(fileBytes);
    String mimeType = mimetype ?? getMimeType(fileType, fileName, fileBytes);

    final fileSizeKB = (fileBytes.length / 1024).toStringAsFixed(1);
    WhatsappLogger.log(
      "sendFileMessage: fileName=$fileName, fileSize=${fileSizeKB}KB, "
      "mimeType=$mimeType, type=$fileType",
    );

    // Map MIME type prefix to WPP-compatible file type.
    // WPP expects: "image", "audio", "video", or "document".
    String mimePrefix = mimeType.split("/").first;
    String fileTypeName;
    switch (mimePrefix) {
      case "image":
        fileTypeName = "image";
        break;
      case "audio":
        fileTypeName = "audio";
        break;
      case "video":
        fileTypeName = "video";
        break;
      default:
        fileTypeName = "document";
        break;
    }

    String? replyTextId = replyMessageId?.serialized;
    String? buttonsText = buttons != null
        ? jsonEncode(buttons.map((e) => e.toJson()).toList())
        : null;

    // For large files, skip building the full data URI string in JS entirely.
    // Instead, send raw base64 chunks and decode each to binary immediately.
    // This avoids O(n²) string concatenation and reduces memory pressure.
    final blobKey = '__wpp_file_blob_${DateTime.now().millisecondsSinceEpoch}';
    const int chunkSize = 2 * 1024 * 1024; // 2MB chunks (base64 chars)
    // Ensure chunks align to 4-char base64 boundaries for valid atob()
    const int alignedChunkSize = (chunkSize ~/ 4) * 4;

    if (base64Image.length > alignedChunkSize) {
      final numChunks = (base64Image.length / alignedChunkSize).ceil();
      WhatsappLogger.log(
        "sendFileMessage: large file, injecting in $numChunks chunks",
      );

      // Initialize a byte array collector in JS
      await wpClient.evaluateJs(
        'window.__wpp_byte_chunks = [];',
        tryPromise: false,
      );

      // Send each base64 chunk → decode to Uint8Array immediately
      for (int i = 0; i < base64Image.length; i += alignedChunkSize) {
        final end = (i + alignedChunkSize > base64Image.length)
            ? base64Image.length
            : i + alignedChunkSize;
        final chunk = base64Image.substring(i, end);
        await wpClient.evaluateJs(
          '''(function() {
            var b64 = ${chunk.jsParse};
            var raw = atob(b64);
            var arr = new Uint8Array(raw.length);
            for (var j = 0; j < raw.length; j++) arr[j] = raw.charCodeAt(j);
            window.__wpp_byte_chunks.push(arr);
          })();''',
          tryPromise: false,
        );
      }

      WhatsappLogger.log("sendFileMessage: chunks injected, building File");

      // Build the final File from all binary chunks
      await wpClient.evaluateJs(
        '''(function() {
          var blob = new Blob(window.__wpp_byte_chunks, {type: ${mimeType.jsParse}});
          var fname = ${fileName.jsParse} || 'file';
          window['$blobKey'] = new File([blob], fname, {type: ${mimeType.jsParse}});
          delete window.__wpp_byte_chunks;
        })();''',
        tryPromise: false,
      );
    } else {
      // Small file: inject as data URI and convert in one shot
      String fileData = "data:$mimeType;base64,$base64Image";
      await wpClient.evaluateJs(
        '''(function() {
          var dataUri = ${fileData.jsParse};
          var parts = dataUri.split(',');
          var mime = parts[0].match(/:(.*?);/)[1];
          var b64 = parts[1];
          var byteChars = atob(b64);
          var byteArrays = [];
          for (var offset = 0; offset < byteChars.length; offset += 8192) {
            var slice = byteChars.slice(offset, offset + 8192);
            var byteNumbers = new Array(slice.length);
            for (var i = 0; i < slice.length; i++) {
              byteNumbers[i] = slice.charCodeAt(i);
            }
            byteArrays.push(new Uint8Array(byteNumbers));
          }
          var blob = new Blob(byteArrays, {type: mime});
          var fname = ${fileName.jsParse} || 'file';
          window['$blobKey'] = new File([blob], fname, {type: mime});
        })();''',
        tryPromise: false,
      );
    }

    WhatsappLogger.log("sendFileMessage: Blob created, sending...");

    // Bypass WPP.chat.sendFileMessage and use low-level WPP internals.
    // The high-level API hangs because chat.msgs.on('add') never fires
    // on some Windows WebView2 setups. Instead we call the WPP internals
    // directly and poll for the sent message.
    final resultKey =
        '__wpp_send_result_${DateTime.now().millisecondsSinceEpoch}';
    final jsTimeoutMs = timeout.inMilliseconds;

    String wrappedSource = '''(function() {
      window['$resultKey'] = null;

      (async function() {
        try {
          var fileObj = window['$blobKey'];
          var chat = await window.WPP.chat.find(${phone.phoneParse});
          if (!chat) throw new Error('Chat not found');

          // Snapshot current message count
          var msgCountBefore = chat.msgs ? chat.msgs.length : 0;

          var opaqueData = await window.WPP.whatsapp.OpaqueData.createFromData(fileObj, fileObj.type);

          var rawMediaOptions = {};
          var fileTypeName = ${fileTypeName.jsParse};
          if (fileTypeName === 'document') rawMediaOptions.asDocument = true;
          else if (fileTypeName === 'audio') rawMediaOptions.isPtt = ${audioAsPtt.jsParse};
          else if (fileTypeName === 'image') rawMediaOptions.maxDimension = 1600;

          var mediaPrep = window.WPP.whatsapp.MediaPrep.prepRawMedia(opaqueData, rawMediaOptions);
          await mediaPrep.waitForPrep();

          // Build send options
          var captionText = ${caption.jsParse} || fileObj.name;
          var sendOptions = {
            caption: captionText,
            filename: fileObj.name,
            footer: ${templateFooter.jsParse} || undefined,
            quotedMsg: ${replyTextId.jsParse} || undefined,
            isCaptionByUser: ${caption.jsParse} != null,
            type: fileTypeName,
            isViewOnce: ${isViewOnce.jsParse} || undefined,
            useTemplateButtons: ${useTemplate.jsParse},
            buttons: $buttonsText,
            title: ${templateTitle.jsParse} || undefined,
            addEvenWhilePreparing: false
          };

          var sendResultPromise;
          if (mediaPrep.sendToChat.length === 1) {
            sendResultPromise = mediaPrep.sendToChat({ chat: chat, options: sendOptions });
          } else {
            sendResultPromise = mediaPrep.sendToChat(chat, sendOptions);
          }

          // Poll for the new outgoing message (replaces broken on('add') listener)
          var pollStart = Date.now();
          var maxPollMs = $jsTimeoutMs;
          var sentMsg = null;

          // Helper: find the latest outgoing media message in chat
          function findSentMsg() {
            if (!chat.msgs || chat.msgs.length <= msgCountBefore) return null;
            var models = chat.msgs.models || chat.msgs._models || [];
            for (var i = models.length - 1; i >= Math.max(0, models.length - 10); i--) {
              var m = models[i];
              if (m && m.id && m.id.fromMe && m.t && (m.t * 1000) > (pollStart - 5000)) {
                var mType = m.type || '';
                if (mType === 'image' || mType === 'ptt' || mType === 'audio' ||
                    mType === 'video' || mType === 'document' || mType === 'sticker') {
                  return m;
                }
              }
            }
            return null;
          }

          function buildMsgResult(m) {
            var msgId = m.id;
            return {
              id: msgId ? {fromMe: msgId.fromMe, remote: msgId.remote ? msgId.remote.toString() : '', id: msgId.id, _serialized: msgId._serialized || msgId.toString()} : null,
              ack: m.ack,
              from: m.from ? m.from.toString() : '',
              to: m.to ? m.to.toString() : '',
              sendMsgResult: {messageSendResult: 'OK'}
            };
          }

          while (Date.now() - pollStart < maxPollMs) {
            await new Promise(function(r) { setTimeout(r, 1500); });
            try {
              var raceResult = await Promise.race([
                sendResultPromise,
                new Promise(function(r) { setTimeout(function() { r('__still_pending__'); }, 200); })
              ]);
              if (raceResult !== '__still_pending__') {
                // Look up the actual message from chat.msgs for full details.
                await new Promise(function(r) { setTimeout(r, 500); });
                var resolvedMsg = findSentMsg();
                if (resolvedMsg) {
                  window['$resultKey'] = JSON.stringify({ok: true, data: buildMsgResult(resolvedMsg)});
                } else {
                  window['$resultKey'] = JSON.stringify({ok: true, data: raceResult});
                }
                return;
              }
            } catch(sendErr) {
              // sendResult rejected, continue polling
            }

            // Check for new fromMe messages in chat
            sentMsg = findSentMsg();
            if (sentMsg) {
              break;
            }
          }

          if (sentMsg) {
            window['$resultKey'] = JSON.stringify({ok: true, data: buildMsgResult(sentMsg)});
          } else {
            window['$resultKey'] = JSON.stringify({ok: false, error: 'sendFileMessage: message not confirmed within timeout'});
          }

        } catch(err) {
          window['$resultKey'] = JSON.stringify({ok: false, error: err ? (err.message || String(err)) : 'Unknown error'});
        }
      })();
    })();''';

    await wpClient.evaluateJs(wrappedSource, tryPromise: false);
    WhatsappLogger.log("sendFileMessage: send started, polling for result...");

    // Poll Dart-side for the JS result
    final stopwatch = Stopwatch()..start();
    int pollCount = 0;

    try {
      while (stopwatch.elapsed < timeout + const Duration(seconds: 10)) {
        final interval = pollCount < 10
            ? const Duration(seconds: 1)
            : const Duration(seconds: 3);
        await Future.delayed(interval);
        pollCount++;

        var check = await wpClient.evaluateJs(
          'window["$resultKey"]',
          tryPromise: false,
        );

        if (check != null && check != 'null' && check.toString().isNotEmpty) {
          dynamic parsed;
          try {
            parsed = check is String ? jsonDecode(check) : check;
          } catch (_) {
            parsed = check;
          }

          if (parsed is Map) {
            if (parsed['ok'] == true) {
              WhatsappLogger.log(
                "sendFileMessage: sent successfully in "
                "${stopwatch.elapsed.inSeconds}s",
              );
              return Message.parse(parsed['data']).firstOrNull;
            } else {
              final errorMsg = parsed['error']?.toString() ?? 'Unknown error';
              WhatsappLogger.log("sendFileMessage: error - $errorMsg");
              throw WhatsappException(
                message: "sendFileMessage failed: $errorMsg",
                exceptionType: WhatsappExceptionType.failedToSend,
              );
            }
          }

          return Message.parse(parsed).firstOrNull;
        }
      }

      WhatsappLogger.log(
        "sendFileMessage: TIMEOUT after ${timeout.inSeconds}s",
      );
      throw WhatsappException(
        message: "sendFileMessage timed out after ${timeout.inSeconds}s",
        exceptionType: WhatsappExceptionType.failedToSend,
      );
    } finally {
      await wpClient.evaluateJs(
        'delete window["$resultKey"]; delete window.__wpp_file_data; delete window["$blobKey"];',
        tryPromise: false,
      );
    }
  }

  Future<Message?> sendContactCard({
    required String phone,
    required String contactPhone,
    required String contactName,
  }) async {
    var result = await wpClient
        .evaluateJs('''window.WPP.chat.sendVCardContactMessage(${phone.phoneParse}, {
            id: ${contactPhone.phoneParse},
            name: ${contactName.jsParse}
          });''', methodName: "sendContactCard");
    return Message.parse(result).firstOrNull;
  }

  ///send a locationMessage using [sendLocationMessage]
  Future<Message?> sendLocationMessage({
    required String phone,
    required String lat,
    required String long,
    String? name,
    String? address,
    String? url,
  }) async {
    var result = await wpClient
        .evaluateJs('''window.WPP.chat.sendLocationMessage(${phone.phoneParse}, {
              lat: ${lat.jsParse},
              lng: ${long.jsParse},
              name: ${name.jsParse},
              address: ${address.jsParse},
              url: ${url.jsParse},
            });
            ''', methodName: "sendLocationMessage");
    return Message.parse(result).firstOrNull;
  }

  ///Pass phone with correct format in [archive] , and
  ///archive = true to archive , and false to unarchive
  Future<void> archive({required String phone, bool archive = true}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.archive(${phone.phoneParse}, $archive);''',
      methodName: "Archive",
    );
  }

  /// check if the given Phone number is a valid phone number
  Future<bool> isValidContact({required String phone}) async {
    await wpClient.evaluateJs(
      '''window.WPP.contact.queryExists(${phone.phoneParse});''',
      methodName: "isValidContact",
    );
    // return true by default , it will crash on any issue
    return true;
  }

  /// to check if we [canMute] phone number
  Future<bool> canMute({required String phone}) async {
    final result = await wpClient
        .evaluateJs('''window.WPP.chat.canMute(${phone.phoneParse});''',
            methodName: "CanMute");
    return result == true || result?.toString() == "true";
  }

  ///Mute a chat, you can use  expiration and use unix timestamp (seconds only)
  Future mute({
    required String phone,
    required int expirationUnixTimeStamp,
  }) async {
    if (!await canMute(phone: phone)) throw "Cannot Mute $phone";
    return await wpClient.evaluateJs(
        '''window.WPP.chat.mute(${phone.phoneParse},{expiration: $expirationUnixTimeStamp});''',
        methodName: "Mute");
  }

  /// Un mute chat
  Future unmute({required String phone}) async {
    return await wpClient.evaluateJs(
        '''window.WPP.chat.unmute(${phone.phoneParse});''',
        methodName: "unmute");
  }

  /// [clear] chat
  Future clear({
    required String phone,
    bool keepStarred = false,
  }) async =>
      await wpClient.evaluateJs(
          '''window.WPP.chat.clear(${phone.phoneParse},$keepStarred);''',
          methodName: "ClearChat");

  /// [delete] chat
  Future delete({
    required String phone,
  }) async =>
      await wpClient.evaluateJs('''window.WPP.chat.delete(${phone.phoneParse});''',
          methodName: "DeleteChat");

  ///Get timestamp of last seen using [getLastSeen]
  /// return either a timestamp or 0 if last seen off
  Future<int?> getLastSeen({required String phone}) async {
    var lastSeen = await wpClient.evaluateJs(
        '''window.WPP.chat.getLastSeen(${phone.phoneParse});''',
        methodName: "GetLastSeen");
    if (lastSeen.runtimeType == bool) return lastSeen ? 1 : 0;
    if (lastSeen.runtimeType == int) return lastSeen;
    return null;
  }

  /// get all Chats using [getChats]
  Future getChats({
    bool onlyUser = false,
    bool onlyGroups = false,
  }) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.list({
            onlyUsers: ${onlyUser.jsParse},
            onlyGroups: ${onlyGroups.jsParse}
         });''',
      methodName: "GetChats",
      forceJsonParseResult: true,
    );
  }

  ///Mark a chat as read and send SEEN event
  Future markAsSeen({required String phone}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.markIsRead(${phone.phoneParse});''',
      methodName: "MarkIsRead",
    );
  }

  Future markIsComposing({required String phone, int timeout = 5000}) async {
    await wpClient.evaluateJs(
      '''window.WPP.chat.markIsComposing(${phone.phoneParse});''',
      methodName: "markIsComposing",
    );

    // Wait for the timeout period.
    await Future.delayed(Duration(milliseconds: timeout));

    // Mark the chat as paused.
    await wpClient.evaluateJs(
      '''window.WPP.chat.markIsPaused(${phone.phoneParse});''',
      methodName: "markIsPaused",
    );
  }

  Future markIsRecording({required String phone, int timeout = 5000}) async {
    await wpClient.evaluateJs(
      '''window.WPP.chat.markIsRecording(${phone.phoneParse});''',
      methodName: "markIsRecording",
    );

    // Wait for the timeout period.
    await Future.delayed(Duration(milliseconds: timeout));

    // Mark the chat as paused.
    await wpClient.evaluateJs(
      '''window.WPP.chat.markIsPaused(${phone.phoneParse});''',
      methodName: "markIsPaused",
    );
  }

  ///Mark a chat as unread
  Future markAsUnread({required String phone}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.markIsUnread(${phone.phoneParse});''',
      methodName: "MarkIsUnread",
    );
  }

  ///pin/unpin to chat
  Future pin({required String phone, bool pin = true}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.pin(${phone.phoneParse},$pin);''',
      methodName: "pin",
    );
  }

  /// Delete message
  /// Set revoke: true if you want to delete for everyone in group chat
  Future deleteMessage({
    required String phone,
    required String messageId,
    bool deleteMediaInDevice = false,
    bool revoke = false,
  }) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.deleteMessage(${phone.phoneParse},${messageId.jsParse}, $deleteMediaInDevice, $revoke);''',
      methodName: "deleteMessage",
    );
  }

  /// Download the base64 of a media message
  Future<Map<String, dynamic>?> downloadMedia({
    required MessageId messageId,
  }) async {
    String mediaSerialized = messageId.serialized;
    String? base64 = await wpClient.evaluateJs(
      '''window.WPP.chat.downloadMedia(${mediaSerialized.jsParse}).then(window.WPP.util.blobToBase64);''',
      methodName: "downloadMedia",
    );
    if (base64 == null) return null;
    return base64ToMap(base64);
  }

  /// Fetch messages from a chat
  Future getMessages({required String phone, int count = -1}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.getMessages(${phone.phoneParse},{count: $count,});''',
      methodName: "getMessages",
      forceJsonParseResult: true,
    );
  }

  /// Send a create poll message , Note: This only works for groups
  Future<Message?> sendCreatePollMessage(
      {required String phone,
      required String pollName,
      required List<String> pollOptions}) async {
    var result = await wpClient.evaluateJs(
      '''window.WPP.chat.sendCreatePollMessage(${phone.phoneParse},${pollName.jsParse},${pollOptions.jsParse});''',
      methodName: "sendCreatePollMessage",
    );
    return Message.parse(result).firstOrNull;
  }

  /// [rejectCall] will reject incoming call
  Future<bool> rejectCall({String? callId}) async {
    var result = await wpClient.evaluateJs(
      '''window.WPP.call.rejectCall(${callId.jsParse});''',
      methodName: "RejectCallResult",
    );
    return result == true || result?.toString() == "true";
  }

  /// Emoji list: https://unicode.org/emoji/charts/full-emoji-list.html
  /// To remove reaction, set [emoji] to null
  Future sendReactionToMessage({
    required MessageId messageId,
    String? emoji,
  }) async {
    String? serialized = messageId.serialized;
    return await wpClient.evaluateJs(
      '''window.WPP.chat.sendReactionToMessage(${serialized.jsParse}, ${emoji != null ? emoji.jsParse : false});''',
      methodName: "sendReactionToMessage",
    );
  }

  /// [forwardTextMessage] may throw errors if passed an invalid contact
  /// or if this method completed without any issue , then probably message sent successfully
  Future<Message?> forwardTextMessage({
    required String phone,
    required MessageId messageId,
    bool displayCaptionText = false,
    bool multicast = false,
  }) async {
    String? serialized = messageId.serialized;
    var result = await wpClient.evaluateJs(
        '''window.WPP.chat.forwardMessage(${phone.phoneParse}, ${serialized.jsParse}, {
            displayCaptionText: $displayCaptionText,
            multicast: $multicast,
          });''',
        methodName: "forwardMessage");
    return Message.parse(result).firstOrNull;
  }

  /// Edit a message you sent
  Future<Message?> editMessage({
    required MessageId messageId,
    required String newMessage,
  }) async {
    var result = await wpClient.evaluateJs(
      '''window.WPP.chat.editMessage(${messageId.serialized.jsParse}, ${newMessage.jsParse});''',
      methodName: "editMessage",
    );
    return Message.parse(result).firstOrNull;
  }

  /// Pin a message in a chat
  Future pinMessage({
    required MessageId messageId,
    int? durationInSeconds,
  }) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.pinMsg(${messageId.serialized.jsParse}, {
        duration: ${durationInSeconds ?? 86400}
      });''',
      methodName: "pinMessage",
    );
  }

  /// Unpin a message in a chat
  Future unpinMessage({required MessageId messageId}) async {
    return await wpClient.evaluateJs(
      '''window.WPP.chat.unpinMsg(${messageId.serialized.jsParse});''',
      methodName: "unpinMessage",
    );
  }
}
