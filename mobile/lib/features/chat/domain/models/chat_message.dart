/// A single message inside a ChatThread.
class ChatMessage {
  final int id;
  final int thread;
  final int sender;
  final String senderName;
  final String senderRole;
  final String body;
  final DateTime sentAt;
  final bool isRead;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.thread,
    required this.sender,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.sentAt,
    required this.isRead,
    this.readAt,
  });

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _safeInt(json['id']),
      thread: _safeInt(json['thread']),
      sender: _safeInt(json['sender']),
      senderName: (json['sender_name'] ?? '') as String,
      senderRole: (json['sender_role'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      isRead: (json['is_read'] ?? false) as bool,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }
}
