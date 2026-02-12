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
  final DateTime createdAt;
  final DateTime updatedAt;

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
    required this.createdAt,
    required this.updatedAt,
  });

  factory ApplicantDocument.fromJson(Map<String, dynamic> json) {
    // Handle document_type - can be ID (int) or nested object
    final docType = json['document_type'];
    int docTypeId;
    String? docTypeName;
    
    if (docType is Map) {
      docTypeId = docType['id'] as int;
      docTypeName = docType['name'] as String?;
    } else {
      docTypeId = docType as int;
      docTypeName = null; // Will be resolved from document types list
    }

    return ApplicantDocument(
      id: json['id'] as int,
      documentType: docTypeId,
      documentTypeName: docTypeName,
      file: json['file'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      ocrText: json['ocr_text'] as String?,
      ocrData: json['ocr_data'] as Map<String, dynamic>?,
      ocrProcessedAt: json['ocr_processed_at'] != null
          ? DateTime.parse(json['ocr_processed_at'] as String)
          : null,
      reviewStatus: json['review_status'] as String? ?? 'PENDING',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
