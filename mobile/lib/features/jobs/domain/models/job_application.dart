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

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: json['id'] as int,
      applicant: json['applicant'] as int,
      applicantName: json['applicant_name'] as String?,
      applicantEmail: json['applicant_email'] as String?,
      job: json['job'] as int,
      jobTitle: json['job_title'] as String?,
      companyName: json['company_name'] as String?,
      status: json['status'] as String,
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
