import 'package:flutter/material.dart';
import 'application_status_history.dart';

class JobApplication {
  final int id;
  final int applicant;
  final String? applicantName;
  final String? applicantEmail;
  final int job;
  final String? jobTitle;
  final String? companyName;
  final String status;
  final String source;
  final DateTime appliedAt;
  final DateTime? reviewedAt;
  final DateTime? placementEndDate;
  final DateTime? cooldownEligibleDate;
  final int? assignedBy;
  final String? assignedByName;
  final String? notes;
  final List<ApplicationStatusHistory> statusHistory;
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
    this.source = 'SELF_APPLIED',
    required this.appliedAt,
    this.reviewedAt,
    this.placementEndDate,
    this.cooldownEligibleDate,
    this.assignedBy,
    this.assignedByName,
    this.notes,
    this.statusHistory = const [],
    required this.createdAt,
    required this.updatedAt,
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

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    final historyList = json['status_history'];
    final history = historyList is List
        ? historyList
            .map((e) => ApplicationStatusHistory.fromJson(
                e as Map<String, dynamic>))
            .toList()
        : <ApplicationStatusHistory>[];

    return JobApplication(
      id: _safeInt(json['id']),
      applicant: _safeInt(json['applicant']),
      applicantName: json['applicant_name']?.toString(),
      applicantEmail: json['applicant_email']?.toString(),
      job: _safeInt(json['job']),
      jobTitle: json['job_title']?.toString(),
      companyName: json['company_name']?.toString(),
      status: (json['status'] ?? '') as String,
      source: (json['source'] ?? 'SELF_APPLIED') as String,
      appliedAt: DateTime.parse(json['applied_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      placementEndDate: json['placement_end_date'] != null
          ? DateTime.parse(json['placement_end_date'] as String)
          : null,
      cooldownEligibleDate: json['cooldown_eligible_date'] != null
          ? DateTime.parse(json['cooldown_eligible_date'] as String)
          : null,
      assignedBy: _safeIntOrNull(json['assigned_by']),
      assignedByName: json['assigned_by_name']?.toString(),
      notes: json['notes'] as String?,
      statusHistory: history,
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
      case 'SHORTLISTED':
        return 'Shortlist';
      case 'OFFERED':
        return 'Ditawarkan';
      case 'OFFER_ACCEPTED':
        return 'Tawaran Diterima';
      case 'OFFER_DECLINED':
        return 'Tawaran Ditolak';
      case 'PLACED':
        return 'Ditempatkan';
      case 'COMPLETED':
        return 'Selesai Bekerja';
      case 'REJECTED':
        return 'Ditolak';
      case 'WITHDRAWN':
        return 'Dicabut';
      default:
        return status;
    }
  }

  String get sourceDisplay =>
      source == 'ADMIN_ASSIGN' ? 'Penugasan Admin' : 'Mandiri';

  Color get statusColor {
    switch (status) {
      case 'APPLIED':
      case 'UNDER_REVIEW':
      case 'SHORTLISTED':
        return const Color(0xFF17A2B8); // info
      case 'OFFERED':
      case 'OFFER_ACCEPTED':
      case 'PLACED':
      case 'COMPLETED':
        return const Color(0xFF28A745); // success
      case 'OFFER_DECLINED':
      case 'REJECTED':
        return const Color(0xFFDC3545); // error
      case 'WITHDRAWN':
        return const Color(0xFF999999); // neutral
      default:
        return const Color(0xFF666666);
    }
  }

  /// Whether this is a terminal status — no further transitions by the applicant.
  bool get isTerminal =>
      status == 'COMPLETED' ||
      status == 'REJECTED' ||
      status == 'WITHDRAWN' ||
      status == 'OFFER_DECLINED';
}
