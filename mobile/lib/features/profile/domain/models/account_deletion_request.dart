import '../../../../core/utils/api_datetime.dart';

class AccountDeletionRequest {
  final int id;
  final String? reason;
  final String status; // PENDING, APPROVED, REJECTED, CANCELLED
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? adminNotes;

  const AccountDeletionRequest({
    required this.id,
    this.reason,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    this.adminNotes,
  });

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequest(
      id: json['id'] as int,
      reason: json['reason'] as String?,
      status: json['status'] as String,
      requestedAt:
          ApiDateTime.parseRequired(json['requested_at'], fieldName: 'requested_at'),
      reviewedAt: ApiDateTime.parse(json['reviewed_at']),
      adminNotes: json['admin_notes'] as String?,
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'PENDING':
        return 'Menunggu Review';
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      case 'CANCELLED':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  bool get isPending => status == 'PENDING';
  bool get canBeCancelled => status == 'PENDING';
}
