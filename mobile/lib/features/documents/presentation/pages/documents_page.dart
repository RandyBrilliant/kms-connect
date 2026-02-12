import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../domain/models/applicant_document.dart';
import '../../domain/models/document_type.dart';
import '../../data/providers/document_provider.dart';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(myDocumentsProvider);
    final documentTypesAsync = ref.watch(documentTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.documents),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/documents/upload');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myDocumentsProvider);
          ref.invalidate(documentTypesProvider);
        },
        child: documentsAsync.when(
          data: (documents) => documentTypesAsync.when(
            data: (types) => _buildDocumentsList(context, ref, documents, types),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(myDocumentsProvider),
                  child: const Text(AppStrings.retry),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/documents/upload');
        },
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _buildDocumentsList(
    BuildContext context,
    WidgetRef ref,
    List<ApplicantDocument> documents,
    List<DocumentType> types,
  ) {
    if (documents.isEmpty && types.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              AppStrings.noData,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textMedium,
                  ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/documents/upload');
              },
              icon: const Icon(Icons.add),
              label: const Text('Unggah Dokumen'),
            ),
          ],
        ),
      );
    }

    // Group documents by type
    final documentsByType = <int, ApplicantDocument>{};
    for (var doc in documents) {
      documentsByType[doc.documentType] = doc;
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        final document = documentsByType[type.id];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: document != null
                  ? AppColors.success
                  : type.isRequired
                      ? AppColors.error
                      : AppColors.textLight,
              child: Icon(
                document != null ? Icons.check : Icons.description,
                color: AppColors.white,
              ),
            ),
            title: Text(
              type.name,
              style: TextStyle(
                fontWeight: document != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: document != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${document.reviewStatusDisplay}'),
                      Text(
                        'Diunggah: ${DateFormat('dd MMM yyyy', 'id_ID').format(document.uploadedAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  )
                : Text(
                    type.isRequired ? 'Wajib - Belum diunggah' : 'Opsional',
                    style: TextStyle(
                      color: type.isRequired ? AppColors.error : AppColors.textMedium,
                    ),
                  ),
            trailing: document != null
                ? PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('Lihat'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Hapus'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        _handleDelete(context, ref, document.id);
                      }
                    },
                  )
                : null,
            onTap: document != null
                ? () {
                    // TODO: View document
                  }
                : () {
                    context.push('/documents/upload?type=${type.id}');
                  },
          ),
        );
      },
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref, int documentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Dokumen'),
        content: const Text('Apakah Anda yakin ingin menghapus dokumen ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(documentRepositoryProvider);
        await repository.deleteDocument(documentId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumen berhasil dihapus'),
              backgroundColor: AppColors.success,
            ),
          );
          ref.invalidate(myDocumentsProvider);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus dokumen: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
