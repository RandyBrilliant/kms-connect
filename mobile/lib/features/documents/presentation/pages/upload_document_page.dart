import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../data/providers/document_provider.dart';
import '../../data/repositories/document_repository.dart';

class UploadDocumentPage extends ConsumerStatefulWidget {
  final int? documentTypeId;

  const UploadDocumentPage({super.key, this.documentTypeId});

  @override
  ConsumerState<UploadDocumentPage> createState() => _UploadDocumentPageState();
}

class _UploadDocumentPageState extends ConsumerState<UploadDocumentPage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  int? _selectedDocumentTypeId;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedDocumentTypeId = widget.documentTypeId;
  }

  Future<void> _pickFile() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          _selectedFile = File(file.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih file: $e')),
        );
      }
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih file terlebih dahulu')),
      );
      return;
    }

    if (_selectedDocumentTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih tipe dokumen')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final repository = ref.read(documentRepositoryProvider);
      await repository.uploadDocument(
        documentTypeId: _selectedDocumentTypeId!,
        file: _selectedFile!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumen berhasil diunggah'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.refresh(myDocumentsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah dokumen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentTypesAsync = ref.watch(documentTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.uploadDocument),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            documentTypesAsync.when(
              data: (types) => DropdownButtonFormField<int>(
                initialValue: _selectedDocumentTypeId,
                decoration: const InputDecoration(
                  labelText: 'Tipe Dokumen *',
                  prefixIcon: Icon(Icons.description),
                ),
                items: types.map((type) {
                  return DropdownMenuItem(
                    value: type.id,
                    child: Row(
                      children: [
                        Text(type.name),
                        if (type.isRequired)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              '*',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDocumentTypeId = value;
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
            const SizedBox(height: 24),
            if (_selectedFile != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryDarkGreen),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedFile!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Pilih File'),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_isUploading || _selectedFile == null) ? null : _handleUpload,
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Unggah'),
            ),
          ],
        ),
      ),
    );
  }
}
