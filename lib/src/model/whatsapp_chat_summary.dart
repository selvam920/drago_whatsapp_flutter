enum WhatsappChatKind { user, group, newsletter }

/// A light, serialisable view of a chat, group or channel -- enough to show it
/// in a picker and to send to it. Pass [id] as the `phone` of any send method.
class WhatsappChatSummary {
  /// The full chat id, e.g. `1203...@g.us` or `1203...@newsletter`.
  final String id;
  final String name;
  final WhatsappChatKind kind;

  /// Group: members count. Channel: subscribers when WhatsApp has loaded it.
  final int? memberCount;

  /// Group: only admins may post. Always false for chats and channels.
  final bool announce;

  /// Group: whether this account is an admin, when WhatsApp exposes it.
  final bool? isAdmin;

  /// Channel: this account's role -- `owner`, `admin`, `subscriber` or
  /// `guest`, when WhatsApp exposes it.
  final String? role;

  const WhatsappChatSummary({
    required this.id,
    required this.name,
    required this.kind,
    this.memberCount,
    this.announce = false,
    this.isAdmin,
    this.role,
  });

  /// Best guess at whether a send from this account will be accepted. Unknown
  /// admin state counts as allowed; WhatsApp still has the final word.
  bool get canPost {
    switch (kind) {
      case WhatsappChatKind.user:
        return true;
      case WhatsappChatKind.group:
        return !announce || isAdmin != false;
      case WhatsappChatKind.newsletter:
        return role == null || role == 'owner' || role == 'admin';
    }
  }

  factory WhatsappChatSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final kind = id.endsWith('@newsletter')
        ? WhatsappChatKind.newsletter
        : id.endsWith('@g.us')
            ? WhatsappChatKind.group
            : WhatsappChatKind.user;
    final count = json['memberCount'];
    return WhatsappChatSummary(
      id: id,
      name: json['name']?.toString() ?? id,
      kind: kind,
      memberCount: count is num ? count.toInt() : null,
      announce: json['announce'] == true,
      isAdmin: json['isAdmin'] is bool ? json['isAdmin'] as bool : null,
      role: json['role']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberCount': memberCount,
        'announce': announce,
        'isAdmin': isAdmin,
        'role': role,
      };

  static List<WhatsappChatSummary> parseList(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => WhatsappChatSummary.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }
}
