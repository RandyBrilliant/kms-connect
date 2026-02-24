import 'applicant_document.dart';
import 'document_type.dart';

/// Combines a [DocumentType] (what should be uploaded) with the user's
/// [ApplicantDocument] (what was actually uploaded), creating a single
/// checklist item that drives the Documents page UI.
class DocumentChecklistItem {
  final DocumentType type;
  final ApplicantDocument? document;

  const DocumentChecklistItem({required this.type, this.document});

  bool get isUploaded => document != null;
  bool get isRequired => type.isRequired;
  bool get isApproved => document?.reviewStatus == 'APPROVED';
  bool get isRejected => document?.reviewStatus == 'REJECTED';
  bool get isPending =>
      isUploaded && document?.reviewStatus == 'PENDING';

  String get statusLabel {
    if (!isUploaded) return 'Belum Diunggah';
    return document!.reviewStatusDisplay;
  }
}
