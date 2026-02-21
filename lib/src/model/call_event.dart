class CallEvent {
  CallEvent({
    required this.id,
    required this.isGroup,
    required this.isVideo,
    required this.offerTime,
    required this.sender,
    required this.peerJid,
  });

  final String id;
  final bool isGroup;
  final bool isVideo;
  final int offerTime;
  final String sender;
  final String peerJid;

  CallEvent copyWith({
    String? id,
    bool? isGroup,
    bool? isVideo,
    int? offerTime,
    String? sender,
    String? peerJid,
  }) {
    return CallEvent(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      isVideo: isVideo ?? this.isVideo,
      offerTime: offerTime ?? this.offerTime,
      sender: sender ?? this.sender,
      peerJid: peerJid ?? this.peerJid,
    );
  }

  static List<CallEvent> parse(dynamic data) {
    if (data == null) return [];
    try {
      if (data is List) {
        return data
            .where((e) => e != null && e is Map)
            .map((e) => CallEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (data is Map) {
        return [CallEvent.fromJson(Map<String, dynamic>.from(data))];
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  factory CallEvent.fromJson(Map<String, dynamic> json) {
    return CallEvent(
      id: json["id"]?.toString() ?? "",
      isGroup: json["isGroup"] == true || json["isGroup"]?.toString() == "true",
      isVideo: json["isVideo"] == true || json["isVideo"]?.toString() == "true",
      offerTime: json["offerTime"] is int
          ? json["offerTime"]
          : (int.tryParse(json["offerTime"]?.toString() ?? "0") ?? 0),
      sender: json["sender"]?.toString() ?? "",
      peerJid: json["peerJid"]?.toString() ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "isGroup": isGroup,
        "isVideo": isVideo,
        "offerTime": offerTime,
        "sender": sender,
        "peerJid": peerJid,
      };
}
