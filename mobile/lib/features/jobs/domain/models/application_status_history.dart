/// An entry in the append-only status audit log for a JobApplication.
class ApplicationStatusHistory {
  final int id;
  final String? fromStatus;
  final String toStatus;
  final int? changedBy;
  final String? changedByName;
  final DateTime changedAt;
  final String? note;

  const ApplicationStatusHistory({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.changedBy,
    this.changedByName,
    required this.changedAt,
    this.note,
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

  factory ApplicationStatusHistory.fromJson(Map<String, dynamic> json) {
    return ApplicationStatusHistory(
      id: _safeInt(json['id']),
      fromStatus: json['from_status']?.toString(),
      toStatus: (json['to_status'] ?? '') as String,
      changedBy: _safeIntOrNull(json['changed_by']),
      changedByName: json['changed_by_name']?.toString(),
      changedAt: DateTime.parse(json['changed_at'] as String),
      note: json['note']?.toString(),
    );
  }

  String get toStatusDisplay {
    switch (toStatus) {
      case 'PRA_SELEKSI':
        return 'Pra-Seleksi';
      case 'INTERVIEW':
        return 'Interview';
      case 'DITERIMA':
        return 'Diterima';
      case 'DITOLAK':
        return 'Ditolak';
      case 'BERANGKAT':
        return 'Berangkat';
      case 'SELESAI':
        return 'Selesai';
      default:
        return toStatus;
    }
  }
}
