import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/document_type.dart';
import '../../domain/models/applicant_document.dart';
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
