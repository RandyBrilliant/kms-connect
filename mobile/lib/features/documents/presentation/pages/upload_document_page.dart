import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../documents/data/providers/document_provider.dart';
import '../../../documents/domain/models/document_type.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class UploadDocumentPage extends ConsumerStatefulWidget {
  const UploadDocumentPage({super.key, this.documentTypeId});
  final int? documentTypeId;

  @override
  ConsumerState<UploadDocumentPage> createState() =>
      _UploadDocumentPageState();
}

class _UploadDocumentPageState
    extends ConsumerState<UploadDocumentPage> {
  final _picker = ImagePicker();
  File? _file;
  DocumentType? _selectedType;
  bool _isUploading = false;

  Future<void> _pickFile(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked != null && mounted) {
      setState(() => _file = File(picked.path));
    }
  }

  void _showSourcePicker() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Pilih Sumber File',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF2563EB)),
                ),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppColors.primaryDarkGreen),
                ),
                title: const Text('Galeri Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpload() async {
    if (_file == null) {
      CustomToast.show(context,
          message: 'Pilih file terlebih dahulu',
          type: ToastType.warning);
      return;
    }
    if (_selectedType == null) {
      CustomToast.show(context,
          message: 'Pilih jenis dokumen terlebih dahulu',
          type: ToastType.warning);
      return;
    }
    setState(() => _isUploading = true);
    try {
      await ref
          .read(documentRepositoryProvider)
          .uploadDocument(
            documentTypeId: _selectedType!.id,
            file: _file!,
          );
      if (!mounted) return;
      setState(() => _isUploading = false);
      ref.invalidate(myDocumentsProvider);
      CustomToast.show(context,
          message: 'Dokumen berhasil diunggah',
          type: ToastType.success);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      CustomToast.show(context,
          message: 'Gagal mengunggah dokumen',
          type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(documentTypesProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const headerH = 140.0;
    final topPad = MediaQuery.paddingOf(context).top;

    // Pre-select type from route arg
    typesAsync.whenData((types) {
      if (_selectedType == null && widget.documentTypeId != null) {
        final match = types.where(
            (t) => t.id == widget.documentTypeId).firstOrNull;
        if (match != null) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _selectedType = match));
        }
      }
    });

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────
          SizedBox(
            height: headerH + topPad,
            child: Stack(
              children: [
                Positioned.fill(
                    child:
                        AuthWaveHeader(height: headerH + topPad)),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, topPad + 10, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white
                                .withValues(alpha: 0.18),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Unggah Dokumen',
                        style: tt.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File picker
                  GestureDetector(
                    onTap: _showSourcePicker,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: _file != null ? 220 : 160,
                      decoration: BoxDecoration(
                        color: _file != null
                            ? Colors.black
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _file != null
                              ? cs.outlineVariant
                              : AppColors.primaryDarkGreen
                                  .withValues(alpha: 0.4),
                          width: _file != null ? 1 : 2,
                          style: _file != null
                              ? BorderStyle.solid
                              : BorderStyle.solid,
                        ),
                      ),
                      child: _file != null
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(15),
                              child: Image.file(
                                _file!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors
                                        .secondaryLightGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.upload_file_rounded,
                                    size: 32,
                                    color: AppColors
                                        .primaryDarkGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Ketuk untuk pilih file',
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        AppColors.primaryDarkGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'JPG, PNG — maks. 5 MB',
                                  style: tt.bodySmall?.copyWith(
                                      color:
                                          cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                    ),
                  ),

                  if (_file != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _showSourcePicker,
                        icon: const Icon(Icons.swap_horiz_rounded,
                            size: 16),
                        label: const Text('Ganti File'),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Type selector
                  Text(
                    'Jenis Dokumen',
                    style: tt.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  typesAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryDarkGreen)),
                    error: (e, s) => Text(
                      'Gagal memuat jenis dokumen',
                      style: tt.bodySmall
                          ?.copyWith(color: AppColors.error),
                    ),
                    data: (types) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: types
                          .map((t) => _TypeChip(
                                type: t,
                                selected: _selectedType?.id == t.id,
                                onTap: () => setState(
                                    () => _selectedType = t),
                              ))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isUploading
                          ? null
                          : _handleUpload,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppColors.primaryDarkGreen,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : Text(
                              'Unggah Dokumen',
                              style: tt.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TypeChip
// ─────────────────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });
  final DocumentType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondaryLightGreen
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primaryDarkGreen
                : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type.isRequired)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Text(
              type.name,
              style: tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primaryDarkGreen
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
