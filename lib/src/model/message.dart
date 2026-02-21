import 'dart:convert';

class Message {
  Message({
    required this.id,
    required this.body,
    required this.type,
    required this.t,
    required this.notifyName,
    required this.from,
    required this.to,
    required this.self,
    required this.isNewMsg,
    required this.star,
    required this.kicNotified,
    required this.recvFresh,
    required this.isFromTemplate,
    required this.pollInvalidated,
    required this.broadcast,
    required this.isForwarded,
    required this.hasReaction,
    required this.ephemeralOutOfSync,
    required this.productHeaderImageRejected,
    required this.lastPlaybackProgress,
    required this.isDynamicReplyButtonsMsg,
    required this.isMdHistoryMsg,
    required this.stickerSentTs,
    required this.requiresDirectConnection,
    required this.pttForwardedFeaturesEnabled,
    required this.caption,
  });

  final MessageId? id;
  final String body;
  final String type;
  final int t;
  final String notifyName;
  final String from;
  final String to;
  final String self;
  final bool isNewMsg;
  final bool star;
  final bool kicNotified;
  final bool recvFresh;
  final bool isFromTemplate;
  final bool pollInvalidated;
  final bool broadcast;
  final bool isForwarded;
  final bool hasReaction;
  final bool ephemeralOutOfSync;
  final bool productHeaderImageRejected;
  final int lastPlaybackProgress;
  final bool isDynamicReplyButtonsMsg;
  final bool isMdHistoryMsg;
  final int stickerSentTs;
  final bool requiresDirectConnection;
  final bool pttForwardedFeaturesEnabled;
  final String caption;

  Message copyWith({
    MessageId? id,
    String? body,
    String? type,
    int? t,
    String? notifyName,
    String? from,
    String? to,
    String? self,
    int? ack,
    bool? isNewMsg,
    bool? star,
    bool? kicNotified,
    bool? recvFresh,
    bool? isFromTemplate,
    bool? pollInvalidated,
    bool? broadcast,
    bool? isForwarded,
    bool? hasReaction,
    bool? ephemeralOutOfSync,
    bool? productHeaderImageRejected,
    int? lastPlaybackProgress,
    bool? isDynamicReplyButtonsMsg,
    bool? isMdHistoryMsg,
    int? stickerSentTs,
    bool? requiresDirectConnection,
    bool? pttForwardedFeaturesEnabled,
    String? caption,
  }) {
    return Message(
      id: id ?? this.id,
      body: body ?? this.body,
      type: type ?? this.type,
      t: t ?? this.t,
      notifyName: notifyName ?? this.notifyName,
      from: from ?? this.from,
      to: to ?? this.to,
      self: self ?? this.self,
      isNewMsg: isNewMsg ?? this.isNewMsg,
      star: star ?? this.star,
      kicNotified: kicNotified ?? this.kicNotified,
      recvFresh: recvFresh ?? this.recvFresh,
      isFromTemplate: isFromTemplate ?? this.isFromTemplate,
      pollInvalidated: pollInvalidated ?? this.pollInvalidated,
      broadcast: broadcast ?? this.broadcast,
      isForwarded: isForwarded ?? this.isForwarded,
      hasReaction: hasReaction ?? this.hasReaction,
      ephemeralOutOfSync: ephemeralOutOfSync ?? this.ephemeralOutOfSync,
      productHeaderImageRejected:
          productHeaderImageRejected ?? this.productHeaderImageRejected,
      lastPlaybackProgress: lastPlaybackProgress ?? this.lastPlaybackProgress,
      isDynamicReplyButtonsMsg:
          isDynamicReplyButtonsMsg ?? this.isDynamicReplyButtonsMsg,
      isMdHistoryMsg: isMdHistoryMsg ?? this.isMdHistoryMsg,
      stickerSentTs: stickerSentTs ?? this.stickerSentTs,
      requiresDirectConnection:
          requiresDirectConnection ?? this.requiresDirectConnection,
      pttForwardedFeaturesEnabled:
          pttForwardedFeaturesEnabled ?? this.pttForwardedFeaturesEnabled,
      caption: caption ?? this.caption,
    );
  }

  /// Because Mobile platforms returns data as list
  /// and desktop returns as map , so to unify the data
  static List<Message> parse(dynamic data) {
    if (data == null) return [];
    try {
      if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        return parse(decoded);
      }
      if (data is List) {
        return data
            .where((e) => e != null && e is Map)
            .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (data is Map) {
        return [Message.fromJson(Map<String, dynamic>.from(data))];
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json["id"] == null
          ? null
          : (json["id"] is Map
              ? MessageId.fromJson(Map<String, dynamic>.from(json["id"]))
              : MessageId(
                  fromMe: false,
                  remote: "",
                  id: "",
                  serialized: json["id"].toString())),
      body: json["body"]?.toString() ?? "",
      type: json["type"]?.toString() ?? "",
      t: json["t"] is int ? json["t"] : (int.tryParse(json["t"]?.toString() ?? "0") ?? 0),
      notifyName: json["notifyName"]?.toString() ?? "",
      from: json["from"]?.toString() ?? "",
      to: json["to"]?.toString() ?? "",
      self: json["self"]?.toString() ?? "",
      isNewMsg: json["isNewMsg"] == true || json["isNewMsg"]?.toString() == "true",
      star: json["star"] == true || json["star"]?.toString() == "true",
      kicNotified: json["kicNotified"] == true || json["kicNotified"]?.toString() == "true",
      recvFresh: json["recvFresh"] == true || json["recvFresh"]?.toString() == "true",
      isFromTemplate: json["isFromTemplate"] == true || json["isFromTemplate"]?.toString() == "true",
      pollInvalidated: json["pollInvalidated"] == true || json["pollInvalidated"]?.toString() == "true",
      broadcast: json["broadcast"] == true || json["broadcast"]?.toString() == "true",
      isForwarded: json["isForwarded"] == true || json["isForwarded"]?.toString() == "true",
      hasReaction: json["hasReaction"] == true || json["hasReaction"]?.toString() == "true",
      ephemeralOutOfSync: json["ephemeralOutOfSync"] == true || json["ephemeralOutOfSync"]?.toString() == "true",
      productHeaderImageRejected: json["productHeaderImageRejected"] == true || json["productHeaderImageRejected"]?.toString() == "true",
      lastPlaybackProgress: json["lastPlaybackProgress"] is int ? json["lastPlaybackProgress"] : (int.tryParse(json["lastPlaybackProgress"]?.toString() ?? "0") ?? 0),
      isDynamicReplyButtonsMsg: json["isDynamicReplyButtonsMsg"] == true || json["isDynamicReplyButtonsMsg"]?.toString() == "true",
      isMdHistoryMsg: json["isMdHistoryMsg"] == true || json["isMdHistoryMsg"]?.toString() == "true",
      stickerSentTs: json["stickerSentTs"] is int ? json["stickerSentTs"] : (int.tryParse(json["stickerSentTs"]?.toString() ?? "0") ?? 0),
      requiresDirectConnection: json["requiresDirectConnection"] == true || json["requiresDirectConnection"]?.toString() == "true",
      pttForwardedFeaturesEnabled: json["pttForwardedFeaturesEnabled"] == true || json["pttForwardedFeaturesEnabled"]?.toString() == "true",
      caption: json["caption"]?.toString() ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id?.toJson(),
        "body": body,
        "type": type,
        "t": t,
        "notifyName": notifyName,
        "from": from,
        "to": to,
        "self": self,
        "isNewMsg": isNewMsg,
        "star": star,
        "kicNotified": kicNotified,
        "recvFresh": recvFresh,
        "isFromTemplate": isFromTemplate,
        "pollInvalidated": pollInvalidated,
        "broadcast": broadcast,
        "isForwarded": isForwarded,
        "hasReaction": hasReaction,
        "ephemeralOutOfSync": ephemeralOutOfSync,
        "productHeaderImageRejected": productHeaderImageRejected,
        "lastPlaybackProgress": lastPlaybackProgress,
        "isDynamicReplyButtonsMsg": isDynamicReplyButtonsMsg,
        "isMdHistoryMsg": isMdHistoryMsg,
        "stickerSentTs": stickerSentTs,
        "requiresDirectConnection": requiresDirectConnection,
        "pttForwardedFeaturesEnabled": pttForwardedFeaturesEnabled,
        "caption": caption,
      };
}

class MessageId {
  MessageId({
    required this.fromMe,
    required this.remote,
    required this.id,
    required this.serialized,
  });

  final bool fromMe;
  final String remote;
  final String id;
  final String serialized;

  MessageId copyWith({
    bool? fromMe,
    String? remote,
    String? id,
    String? serialized,
  }) {
    return MessageId(
      fromMe: fromMe ?? this.fromMe,
      remote: remote ?? this.remote,
      id: id ?? this.id,
      serialized: serialized ?? this.serialized,
    );
  }

  factory MessageId.fromJson(Map<String, dynamic> json) {
    return MessageId(
      fromMe: json["fromMe"] ?? false,
      remote: json["remote"] ?? "",
      id: json["id"] ?? "",
      serialized: json["_serialized"] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "fromMe": fromMe,
        "remote": remote,
        "id": id,
        "_serialized": serialized,
      };
}
