import '../../../../core/utils/api_datetime.dart';

/// Broadcast announcement from admin (pra-seleksi batch and/or interview cohort).
///
/// API merges [BatchAnnouncement] and [InterviewCohortAnnouncement] into one list.
/// Batch rows include `batch`; cohort rows use `cohort` and may set `batch` to null.
/// Optional `kind` / `source_id` identify the source for UI chips.
class BatchAnnouncement {
  final int id;
  /// Pra-seleksi batch id when this row is from a batch announcement; null for cohort-only rows.
  final int? batch;
  /// Interview cohort id when this row is from a cohort announcement.
  final int? cohort;
  final String title;
  final String body;
  /// Optional targeting metadata from admin (e.g. tahapan); may be null for older rows.
  final Map<String, dynamic>? recipientConfig;
  final int? createdBy;
  final String? createdByName;
  final DateTime createdAt;
  /// `"batch"` or `"cohort"` when provided by the merged applications announcements API.
  final String? kind;
  /// Batch id or cohort id matching [kind], when provided.
  final int? sourceId;

  const BatchAnnouncement({
    required this.id,
    this.batch,
    this.cohort,
    required this.title,
    required this.body,
    this.recipientConfig,
    this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.kind,
    this.sourceId,
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
    final rc = json['recipient_config'];
    return BatchAnnouncement(
      id: _safeInt(json['id']),
      batch: _safeIntOrNull(json['batch']),
      cohort: _safeIntOrNull(json['cohort']),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      recipientConfig: rc is Map<String, dynamic> ? rc : null,
      createdBy: _safeIntOrNull(json['created_by']),
      createdByName: json['created_by_name']?.toString(),
      createdAt:
          ApiDateTime.parseRequired(json['created_at'], fieldName: 'created_at'),
      kind: json['kind']?.toString(),
      sourceId: _safeIntOrNull(json['source_id']),
    );
  }
}
