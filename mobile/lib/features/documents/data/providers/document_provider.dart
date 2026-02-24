import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/document_type.dart';
import '../../domain/models/applicant_document.dart';
import '../../domain/models/document_checklist_item.dart';
import '../repositories/document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

final documentTypesProvider = FutureProvider<List<DocumentType>>((ref) async {
  final repository = ref.read(documentRepositoryProvider);
  return await repository.getDocumentTypes();
});

final myDocumentsProvider = FutureProvider<List<ApplicantDocument>>((ref) async {
  final repository = ref.read(documentRepositoryProvider);
  return await repository.getMyDocuments();
});

/// Combines document types with uploaded documents into a single checklist.
/// Each [DocumentChecklistItem] pairs a [DocumentType] with the matching
/// [ApplicantDocument] (if uploaded).
final documentChecklistProvider =
    FutureProvider<List<DocumentChecklistItem>>((ref) async {
  final types = await ref.watch(documentTypesProvider.future);
  final docs = await ref.watch(myDocumentsProvider.future);

  // Build a lookup of uploaded docs by document_type ID.
  final docByType = <int, ApplicantDocument>{};
  for (final doc in docs) {
    docByType[doc.documentType] = doc;
  }

  return types
      .map((type) => DocumentChecklistItem(
            type: type,
            document: docByType[type.id],
          ))
      .toList();
});
