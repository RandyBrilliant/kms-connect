/// Broadcast announcement sent by admin to all applicants in a batch.
///
/// Used on PRA_SELEKSI and INTERVIEW stages as the primary communication
/// channel instead of individual chat threads.
class BatchAnnouncement {
  final int id;
  final int batch;
  final String title;
  final String body;
  final int? createdBy;
  final String? createdByName;
  final DateTime createdAt;

  const BatchAnnouncement({
    required this.id,
    required this.batch,
    required this.title,
    required this.body,
    this.createdBy,
    this.createdByName,
    required this.createdAt,
  });

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }

  static int? _safeIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.toInt();
    return null;
  }

  factory BatchAnnouncement.fromJson(Map<String, dynamic> json) {
    return BatchAnnouncement(
      id: _safeInt(json['id']),
      batch: _safeInt(json['batch']),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      createdBy: _safeIntOrNull(json['created_by']),
      createdByName: json['created_by_name']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
