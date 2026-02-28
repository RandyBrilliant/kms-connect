/// Summary of the last message in a chat thread — used in the inbox list.
class ChatLastMessage {
  final int id;
  final String body;
  final String senderName;
  final String senderRole;
  final DateTime sentAt;
  final bool isRead;

  const ChatLastMessage({
    required this.id,
    required this.body,
    required this.senderName,
    required this.senderRole,
    required this.sentAt,
    required this.isRead,
  });

  factory ChatLastMessage.fromJson(Map<String, dynamic> json) {
    return ChatLastMessage(
      id: _safeInt(json['id']),
      body: (json['body'] ?? '') as String,
      senderName: (json['sender_name'] ?? '') as String,
      senderRole: (json['sender_role'] ?? '') as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      isRead: (json['is_read'] ?? false) as bool,
    );
  }

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }
}

/// Inbox item representing one chat thread between the applicant and admin.
///
/// Fetched from `GET /api/chat/applicant/threads/`.
class ChatThreadPreview {
  /// Thread primary key (used to fetch messages).
  final int id;

  /// The associated job-application ID. Passed to [ChatThreadPage].
  final int applicationId;

  /// Title of the job this thread is about.
  final String jobTitle;

  /// Whether admin closed the thread (no new messages allowed).
  final bool isClosed;

  /// Number of messages from admin that the applicant hasn't read yet.
  final int unreadCount;

  /// Summary of the most recent message, or null if the thread is empty.
  final ChatLastMessage? lastMessage;

  final DateTime updatedAt;
  final DateTime createdAt;

  const ChatThreadPreview({
    required this.id,
    required this.applicationId,
    required this.jobTitle,
    required this.isClosed,
    required this.unreadCount,
    this.lastMessage,
    required this.updatedAt,
    required this.createdAt,
  });

  factory ChatThreadPreview.fromJson(Map<String, dynamic> json) {
    final lastMsgRaw = json['last_message'];
    return ChatThreadPreview(
      id: _safeInt(json['id']),
      applicationId: _safeInt(json['application_id']),
      jobTitle: (json['job_title'] ?? '') as String,
      isClosed: (json['is_closed'] ?? false) as bool,
      unreadCount: _safeInt(json['unread_count']),
      lastMessage: lastMsgRaw is Map<String, dynamic>
          ? ChatLastMessage.fromJson(lastMsgRaw)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }
}
