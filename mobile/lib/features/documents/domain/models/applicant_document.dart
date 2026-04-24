import '../../../../core/utils/api_datetime.dart';

class ApplicantDocument {
  final int id;
  final int documentType;
  final String? documentTypeName;
  final String? file;
  final DateTime uploadedAt;
  final String? ocrText;
  final Map<String, dynamic>? ocrData;
  final DateTime? ocrProcessedAt;
  final String reviewStatus;
  final String reviewNotes;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  ApplicantDocument({
    required this.id,
    required this.documentType,
    this.documentTypeName,
    this.file,
    required this.uploadedAt,
    this.ocrText,
    this.ocrData,
    this.ocrProcessedAt,
    required this.reviewStatus,
    this.reviewNotes = '',
    this.reviewedByName,
    this.reviewedAt,
  });

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }

  factory ApplicantDocument.fromJson(Map<String, dynamic> json) {
    // Handle document_type - can be ID (int) or nested object
    final docType = json['document_type'];
    int docTypeId;
    String? docTypeName;
    
    if (docType is Map) {
      docTypeId = _safeInt(docType['id']);
      docTypeName = docType['name']?.toString();
    } else {
      docTypeId = _safeInt(docType);
      docTypeName = null; // Will be resolved from document types list
    }

    return ApplicantDocument(
      id: _safeInt(json['id']),
      documentType: docTypeId,
      documentTypeName: docTypeName,
      file: json['file'] as String?,
      uploadedAt:
          ApiDateTime.parseRequired(json['uploaded_at'], fieldName: 'uploaded_at'),
      ocrText: json['ocr_text'] as String?,
      ocrData: json['ocr_data'] as Map<String, dynamic>?,
      ocrProcessedAt: ApiDateTime.parse(json['ocr_processed_at']),
      reviewStatus: json['review_status'] as String? ?? 'PENDING',
      reviewNotes: (json['review_notes'] ?? '') as String,
      reviewedByName: json['reviewed_by_name']?.toString(),
      reviewedAt: ApiDateTime.parse(json['reviewed_at']),
    );
  }

  String get reviewStatusDisplay {
    switch (reviewStatus) {
      case 'PENDING':
        return 'Menunggu Review';
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return reviewStatus;
    }
  }

  bool get hasOcrData => ocrData != null && ocrData!.isNotEmpty;
}
