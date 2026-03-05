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
  final int? batch;
  final String? batchName;
  final String status;
  final DateTime? praSeleksiConfirmedAt;
  final DateTime? interviewConfirmedAt;
  final DateTime appliedAt;
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
    this.batch,
    this.batchName,
    required this.status,
    this.praSeleksiConfirmedAt,
    this.interviewConfirmedAt,
    required this.appliedAt,
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
      batch: _safeIntOrNull(json['batch']),
      batchName: json['batch_name']?.toString(),
      status: (json['status'] ?? '') as String,
      praSeleksiConfirmedAt: json['pra_seleksi_confirmed_at'] != null
          ? DateTime.parse(json['pra_seleksi_confirmed_at'] as String)
          : null,
      interviewConfirmedAt: json['interview_confirmed_at'] != null
          ? DateTime.parse(json['interview_confirmed_at'] as String)
          : null,
      appliedAt: DateTime.parse(json['applied_at'] as String),
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

  /// Human-readable label for the current status.
  String get statusDisplay {
    switch (status) {
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
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'PRA_SELEKSI':
      case 'INTERVIEW':
        return const Color(0xFF17A2B8); // info / blue
      case 'DITERIMA':
      case 'BERANGKAT':
        return const Color(0xFF28A745); // success / green
      case 'SELESAI':
        return const Color(0xFF6C757D); // secondary / grey
      case 'DITOLAK':
        return const Color(0xFFDC3545); // error / red
      default:
        return const Color(0xFF666666);
    }
  }

  /// Terminal statuses — no applicant confirmation needed and no further transitions.
  bool get isTerminal => status == 'DITOLAK' || status == 'SELESAI';

  /// Whether the applicant can still confirm attendance at current stage.
  bool get canConfirm {
    if (status == 'PRA_SELEKSI') return praSeleksiConfirmedAt == null;
    if (status == 'INTERVIEW') return interviewConfirmedAt == null;
    return false;
  }

  /// Whether the current stage has been confirmed by the applicant.
  bool get isConfirmed {
    if (status == 'PRA_SELEKSI') return praSeleksiConfirmedAt != null;
    if (status == 'INTERVIEW') return interviewConfirmedAt != null;
    return false;
  }
}

