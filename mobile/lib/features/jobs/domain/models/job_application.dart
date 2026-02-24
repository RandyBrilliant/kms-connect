class JobApplication {
  final int id;
  final int applicant;
  final String? applicantName;
  final String? applicantEmail;
  final int job;
  final String? jobTitle;
  final String? companyName;
  final String status;
  final DateTime appliedAt;
  final DateTime? reviewedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobApplication({
    required this.id,
    required this.applicant,
    this.applicantName,
    this.applicantEmail,
    required this.job,
    this.jobTitle,
    this.companyName,
    required this.status,
    required this.appliedAt,
    this.reviewedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: _safeInt(json['id']),
      applicant: _safeInt(json['applicant']),
      applicantName: json['applicant_name']?.toString(),
      applicantEmail: json['applicant_email']?.toString(),
      job: _safeInt(json['job']),
      jobTitle: json['job_title']?.toString(),
      companyName: json['company_name']?.toString(),
      status: (json['status'] ?? '') as String,
      appliedAt: DateTime.parse(json['applied_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'APPLIED':
        return 'Dilamar';
      case 'UNDER_REVIEW':
        return 'Dalam Review';
      case 'ACCEPTED':
        return 'Diterima';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return status;
    }
  }
}
