import '../../../../core/utils/api_datetime.dart';

class AppNotification {
  final int id;
  final String title;
  final String message;
  final String notificationType;
  final String priority;
  final String? actionUrl;
  final String? actionLabel;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.priority,
    this.actionUrl,
    this.actionLabel,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      notificationType: json['notification_type'] as String? ?? 'INFO',
      priority: json['priority'] as String? ?? 'NORMAL',
      actionUrl: json['action_url'] as String?,
      actionLabel: json['action_label'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: ApiDateTime.parse(json['read_at']),
      createdAt:
          ApiDateTime.parseRequired(json['created_at'], fieldName: 'created_at'),
    );
  }

  AppNotification copyWith({bool? isRead, DateTime? readAt}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      notificationType: notificationType,
      priority: priority,
      actionUrl: actionUrl,
      actionLabel: actionLabel,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
