import 'package:flutter/material.dart';
import 'application_status_history.dart';
import '../../../../core/utils/api_datetime.dart';

class DocumentCollectionProgressItem {
  final String code;
  final String label;
  final bool done;
  /// Whether the pelamar has explicitly confirmed this step.
  final bool confirmed;
  /// Timestamp when the pelamar confirmed this step, or null if not yet confirmed.
  final DateTime? confirmedAt;

  const DocumentCollectionProgressItem({
    required this.code,
    required this.label,
    required this.done,
    this.confirmed = false,
    this.confirmedAt,
  });

  factory DocumentCollectionProgressItem.fromJson(Map<String, dynamic> json) {
    return DocumentCollectionProgressItem(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      done: json['done'] == true,
      confirmed: json['confirmed'] == true,
      confirmedAt: ApiDateTime.parse(json['confirmed_at']),
    );
  }
}

class DocumentCollectionProgress {
  final List<DocumentCollectionProgressItem> items;
  final int doneCount;
  final int totalCount;
  final bool isComplete;

  const DocumentCollectionProgress({
    this.items = const [],
    this.doneCount = 0,
    this.totalCount = 0,
    this.isComplete = false,
  });

  factory DocumentCollectionProgress.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(DocumentCollectionProgressItem.fromJson)
            .toList()
        : <DocumentCollectionProgressItem>[];
    return DocumentCollectionProgress(
      items: items,
      doneCount: JobApplication._safeInt(json['done_count']),
      totalCount: JobApplication._safeInt(json['total_count']),
      isComplete: json['is_complete'] == true,
    );
  }
}

class JobApplication {
  static const List<String> stageOrder = <String>[
    'PRA_SELEKSI',
    'INTERVIEW',
    'CADANGAN',
    'DITERIMA',
    'BERANGKAT',
    'SELESAI',
    'DITOLAK',
  ];

  final int id;
  final int applicant;
  final String? applicantName;
  final String? applicantEmail;
  final int job;
  final String? jobTitle;
  final String? companyName;
  final int? batch;
  final String? batchName;
  /// Pra-seleksi tahapan order/label from `LamaranBatch` (when batch present).
  final int? batchTahapOrder;
  final String? batchTahapLabel;
  /// Interview session group (`InterviewCohort`) after pra-seleksi.
  final int? interviewCohort;
  final String? interviewCohortName;
  final String status;
  final DateTime? praSeleksiDate;
  final String? praSeleksiLocation;
  /// Additional instructions for pra-seleksi (from batch).
  final String? praSeleksiNotes;
  final DateTime? interviewDate;
  final String? interviewLocation;
  /// Additional instructions for interview (from cohort, legacy batch fallback).
  final String? interviewNotes;
  final DateTime? praSeleksiConfirmedAt;
  /// Admin marked passed pra-seleksi (sub-status; still PRA_SELEKSI until interview).
  final bool? praSeleksiPassed;
  final DateTime? praSeleksiPassedAt;
  final DateTime? interviewConfirmedAt;
  final DateTime appliedAt;
  final DateTime? placementEndDate;
  final DateTime? cooldownEligibleDate;
  final int? assignedBy;
  final String? assignedByName;
  final String? notes;
  final List<ApplicationStatusHistory> statusHistory;
  final Map<String, bool> attendanceByStage;
  final Map<String, DateTime?> attendanceMarkedAtByStage;
  final List<String> reachedStages;
  final DocumentCollectionProgress? documentCollectionProgress;
  final bool pengumpulanDokumenComplete;
  /// Current admin-controlled sub-step within DITERIMA.
  /// Example values: MASUK_BERKAS_ASLI, MEDICAL, ..., PERSIAPAN_KEBERANGKATAN.
  final String? diterimaCurrentStep;
  /// Per-step confirmation timestamps for the 9 document-collection steps
  /// within the DITERIMA stage. Keys are step codes (e.g. "MEDICAL").
  /// Value is the DateTime when confirmed, or null if not yet confirmed.
  final Map<String, DateTime?> diterimastepConfirmations;
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
    this.batchTahapOrder,
    this.batchTahapLabel,
    this.interviewCohort,
    this.interviewCohortName,
    required this.status,
    this.praSeleksiDate,
    this.praSeleksiLocation,
    this.praSeleksiNotes,
    this.interviewDate,
    this.interviewLocation,
    this.interviewNotes,
    this.praSeleksiConfirmedAt,
    this.praSeleksiPassed,
    this.praSeleksiPassedAt,
    this.interviewConfirmedAt,
    required this.appliedAt,
    this.placementEndDate,
    this.cooldownEligibleDate,
    this.assignedBy,
    this.assignedByName,
    this.notes,
    this.statusHistory = const [],
    this.attendanceByStage = const {},
    this.attendanceMarkedAtByStage = const {},
    this.reachedStages = const [],
    this.documentCollectionProgress,
    this.pengumpulanDokumenComplete = false,
    this.diterimaCurrentStep,
    this.diterimastepConfirmations = const {},
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

    final attendanceRaw = json['attendance_by_stage'];
    final attendanceByStage = <String, bool>{};
    if (attendanceRaw is Map<String, dynamic>) {
      for (final entry in attendanceRaw.entries) {
        attendanceByStage[entry.key] = entry.value == true;
      }
    }

    final attendanceAtRaw = json['attendance_marked_at_by_stage'];
    final attendanceMarkedAtByStage = <String, DateTime?>{};
    if (attendanceAtRaw is Map<String, dynamic>) {
      for (final entry in attendanceAtRaw.entries) {
        attendanceMarkedAtByStage[entry.key] = ApiDateTime.parse(entry.value);
      }
    }

    final reachedRaw = json['reached_stages'];
    final reachedStages = reachedRaw is List
        ? reachedRaw.map((e) => e.toString()).toList()
        : <String>[];
    final dcpRaw = json['document_collection_progress'];
    final dcp = dcpRaw is Map<String, dynamic>
        ? DocumentCollectionProgress.fromJson(dcpRaw)
        : null;

    final stepConfirmRaw = json['diterima_step_confirmations'];
    final diterimastepConfirmations = <String, DateTime?>{};
    if (stepConfirmRaw is Map<String, dynamic>) {
      for (final entry in stepConfirmRaw.entries) {
        diterimastepConfirmations[entry.key] = ApiDateTime.parse(entry.value);
      }
    }

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
      batchTahapOrder: _safeIntOrNull(json['batch_tahap_order']),
      batchTahapLabel: json['batch_tahap_label']?.toString(),
      interviewCohort: _safeIntOrNull(json['interview_cohort']),
      interviewCohortName: json['interview_cohort_name']?.toString(),
      status: (json['status'] ?? '') as String,
      praSeleksiDate: ApiDateTime.parse(json['pra_seleksi_date']),
      praSeleksiLocation: json['pra_seleksi_location']?.toString(),
      praSeleksiNotes: json['pra_seleksi_notes']?.toString(),
      interviewDate: ApiDateTime.parse(json['interview_date']),
      interviewLocation: json['interview_location']?.toString(),
      interviewNotes: json['interview_notes']?.toString(),
      praSeleksiConfirmedAt: ApiDateTime.parse(json['pra_seleksi_confirmed_at']),
      praSeleksiPassed: json['pra_seleksi_passed'] as bool?,
      praSeleksiPassedAt: ApiDateTime.parse(json['pra_seleksi_passed_at']),
      interviewConfirmedAt: ApiDateTime.parse(json['interview_confirmed_at']),
      appliedAt: ApiDateTime.parseRequired(
        json['applied_at'],
        fieldName: 'applied_at',
      ),
      placementEndDate: ApiDateTime.parse(json['placement_end_date']),
      cooldownEligibleDate: ApiDateTime.parse(json['cooldown_eligible_date']),
      assignedBy: _safeIntOrNull(json['assigned_by']),
      assignedByName: json['assigned_by_name']?.toString(),
      notes: json['notes'] as String?,
      statusHistory: history,
      attendanceByStage: attendanceByStage,
      attendanceMarkedAtByStage: attendanceMarkedAtByStage,
      reachedStages: reachedStages,
      documentCollectionProgress: dcp,
      pengumpulanDokumenComplete: json['pengumpulan_dokumen_complete'] == true,
      diterimaCurrentStep: json['diterima_current_step']?.toString(),
      diterimastepConfirmations: diterimastepConfirmations,
      createdAt: ApiDateTime.parseRequired(
        json['created_at'],
        fieldName: 'created_at',
      ),
      updatedAt: ApiDateTime.parseRequired(
        json['updated_at'],
        fieldName: 'updated_at',
      ),
    );
  }

  /// Human-readable label for the current status.
  String get statusDisplay {
    switch (status) {
      case 'PRA_SELEKSI':
        if (praSeleksiPassed == true) return 'Diterima Pra-Seleksi';
        return 'Pra-Seleksi';
      case 'INTERVIEW':
        return 'Interview';
      case 'CADANGAN':
        return 'Cadangan';
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
      case 'CADANGAN':
        return const Color(0xFFF59E0B); // amber / warning — reserve/standby
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
    return canConfirmStage(status);
  }

  /// Whether the current stage has been confirmed by the applicant.
  bool get isConfirmed {
    return attendanceByStage[status] == true;
  }

  bool canConfirmStage(String stage) {
    final reached = reachedStages.contains(stage) || status == stage;
    if (!reached) return false;
    return attendanceByStage[stage] != true;
  }
}

