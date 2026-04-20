import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/colors.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../core/utils/safe_navigation.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../documents/data/providers/document_provider.dart';
import '../../../documents/domain/models/document_type.dart';
import '../../utils/open_cv_template_pdf.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class UploadDocumentPage extends ConsumerStatefulWidget {
  const UploadDocumentPage({super.key, this.documentTypeId});
  final int? documentTypeId;

  @override
  ConsumerState<UploadDocumentPage> createState() => _UploadDocumentPageState();
}

// PDF document type codes — must match backend document_specs.py
const _pdfDocCodes = {
  'cv',
  'sertifikat-keterampilan',
  'ijin-keluarga',
  'surat-keterangan-pemberi-ijin',
  'surat-kesehatan',
  'surat-keterangan-status-perkawinan',
  'perjanjian-penempatan',
};

class _UploadDocumentPageState extends ConsumerState<UploadDocumentPage> {
  final _picker = ImagePicker();
  File? _file;
  bool _filePdf = false; // true if _file is a PDF
  DocumentType? _selectedType;
  bool _isUploading = false;
  bool _didPreselect = false;

  bool get _isPdf =>
      _selectedType != null && _pdfDocCodes.contains(_selectedType!.code);

  @override
  void initState() {
    super.initState();
    // Pre-select document type from route arg after provider loads
    if (widget.documentTypeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryPreselectType();
      });
    }
  }

  void _tryPreselectType() {
    if (_didPreselect || !mounted) return;
    final typesAsync = ref.read(documentTypesProvider);
    typesAsync.whenData((types) {
      if (_selectedType == null && widget.documentTypeId != null) {
        final match = types
            .where((t) => t.id == widget.documentTypeId)
            .firstOrNull;
        if (match != null) {
          _didPreselect = true;
          setState(() {
            _selectedType = match;
            // Clear any previously picked file since format may differ
            _file = null;
            _filePdf = false;
          });
        }
      }
    });
  }

  // ── Image picker ────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked != null && mounted) {
      setState(() {
        _file = File(picked.path);
        _filePdf = false;
      });
    }
  }

  // ── PDF picker ───────────────────────────────────────────────────────────
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path != null && mounted) {
      setState(() {
        _file = File(path);
        _filePdf = true;
      });
    }
  }

  // ── Unified entry point ──────────────────────────────────────────────────
  /// Opens the system gallery immediately for image types (no extra sheet delay).
  /// PDF types open the file picker directly.
  void _onTapFilePicker() {
    if (_isPdf) {
      _pickPdf();
    } else {
      _pickImage(ImageSource.gallery);
    }
  }

  Future<void> _handleUpload() async {
    if (_file == null) {
      CustomToast.show(
        context,
        message: 'Pilih file terlebih dahulu',
        type: ToastType.warning,
      );
      return;
    }
    if (_selectedType == null) {
      CustomToast.show(
        context,
        message: 'Pilih jenis dokumen terlebih dahulu',
        type: ToastType.warning,
      );
      return;
    }
    setState(() => _isUploading = true);
    try {
      // Compress image documents before upload (skip PDFs).
      final fileToUpload = _filePdf
          ? _file!
          : await ImageCompressor.compressDocument(_file!);
      await ref
          .read(documentRepositoryProvider)
          .uploadDocument(
            documentTypeId: _selectedType!.id,
            file: fileToUpload,
          );
      if (!mounted) return;
      setState(() => _isUploading = false);
      ref.invalidate(myDocumentsProvider);
      ref.invalidate(documentChecklistProvider);
      CustomToast.showGlobal(
        message: 'Dokumen berhasil diunggah',
        type: ToastType.success,
      );
      runWhenNavigatorUnlocked(() {
        if (!mounted) return;
        Navigator.pop(context);
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      final msg = (e.message?.isNotEmpty == true)
          ? e.message!
          : 'Gagal mengunggah dokumen';
      CustomToast.show(context, message: msg, type: ToastType.error);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      CustomToast.show(
        context,
        message: 'Gagal mengunggah dokumen',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(documentTypesProvider);
    final docsAsync = ref.watch(myDocumentsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    // If initState callback ran before data loaded, try again now
    if (!_didPreselect && widget.documentTypeId != null) {
      _tryPreselectType();
    }

    // Check whether the currently selected document type already has an
    // APPROVED document — if so the form is locked.
    final isApproved =
        _selectedType != null &&
        docsAsync.whenOrNull(
              data: (docs) => docs.any(
                (d) =>
                    d.documentType == _selectedType!.id &&
                    d.reviewStatus == 'APPROVED',
              ),
            ) ==
            true;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: ProfessionalGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Kembali',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unggah Dokumen',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Unggah file sesuai jenis dokumen',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    24 + bottomInset + bottomPad,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.min(
                          MediaQuery.sizeOf(context).width - 40,
                          560,
                        ),
                      ),
                      child: ProfessionalCard(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Approved-type banner (shown when doc is locked)
                              if (isApproved) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF6EE7B7),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.lock_rounded,
                                        size: 18,
                                        color: Color(0xFF065F46),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Dokumen Sudah Disetujui',
                                              style: tt.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF065F46),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Dokumen ini telah disetujui oleh tim kami dan tidak dapat diganti.',
                                              style: tt.bodySmall?.copyWith(
                                                color: const Color(0xFF047857),
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Format hint chip (shown only when type selected)
                              if (_selectedType != null) ...[
                                _FormatHintChip(isPdf: _isPdf),
                                const SizedBox(height: 12),
                              ],

                              if (_selectedType?.code == 'cv') ...[
                                _CvTemplateBanner(
                                  onOpen: () => openCvTemplatePdf(context),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // File picker area — InkWell for reliable taps; gallery opens on main tap
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final screenH = MediaQuery.sizeOf(
                                    context,
                                  ).height;
                                  final maxW = constraints.maxWidth;
                                  final emptyH = math.max(
                                    148.0,
                                    math.min(200.0, maxW * 0.42),
                                  );
                                  final previewImgH = math.max(
                                    200.0,
                                    math.min(340.0, screenH * 0.36),
                                  );
                                  final h = _file == null
                                      ? emptyH
                                      : (_filePdf ? 132.0 : previewImgH);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      clipBehavior: Clip.hardEdge,
                                      children: [
                                        Material(
                                          color: isApproved
                                              ? cs.surfaceContainerHighest
                                                    .withValues(alpha: 0.5)
                                              : _file != null
                                              ? (_filePdf
                                                    ? const Color(0xFFF0FDF4)
                                                    : Colors.black)
                                              : cs.surfaceContainerHighest,
                                          child: InkWell(
                                            onTap: isApproved
                                                ? null
                                                : _onTapFilePicker,
                                            splashColor: AppColors
                                                .primaryDarkGreen
                                                .withValues(alpha: 0.12),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              width: double.infinity,
                                              height: h,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: isApproved
                                                      ? cs.outlineVariant
                                                            .withValues(
                                                              alpha: 0.4,
                                                            )
                                                      : _file != null
                                                      ? (_filePdf
                                                            ? AppColors
                                                                  .primaryDarkGreen
                                                            : cs.outlineVariant)
                                                      : AppColors
                                                            .primaryDarkGreen
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                  width: _file != null
                                                      ? 1.5
                                                      : 2,
                                                ),
                                              ),
                                              child: _file != null
                                                  ? _filePdf
                                                        ? _PdfPreview(
                                                            file: _file!,
                                                          )
                                                        : ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                            child: Image.file(
                                                              _file!,
                                                              width: double
                                                                  .infinity,
                                                              height: h,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          )
                                                  : _FilePlaceholder(
                                                      isPdf: _isPdf,
                                                      tt: tt,
                                                      cs: cs,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        if (!isApproved &&
                                            !_isPdf &&
                                            _file == null)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Material(
                                              color: Colors.white.withValues(
                                                alpha: 0.95,
                                              ),
                                              shape: const CircleBorder(),
                                              elevation: 1,
                                              child: InkWell(
                                                customBorder:
                                                    const CircleBorder(),
                                                onTap: () => _pickImage(
                                                  ImageSource.camera,
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Icon(
                                                    Icons.camera_alt_outlined,
                                                    size: 22,
                                                    color: AppColors
                                                        .primaryDarkGreen,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              if (_file != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _onTapFilePicker,
                                    icon: const Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 16,
                                    ),
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
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Note: selecting a different type clears the picked file
                              typesAsync.when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryDarkGreen,
                                  ),
                                ),
                                error: (e, s) => Text(
                                  'Gagal memuat jenis dokumen',
                                  style: tt.bodySmall?.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                                data: (types) {
                                  final sorted = List<DocumentType>.from(types)
                                    ..sort(
                                      (a, b) =>
                                          a.sortOrder.compareTo(b.sortOrder),
                                    );
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: sorted
                                        .map(
                                          (t) => _TypeChip(
                                            type: t,
                                            selected: _selectedType?.id == t.id,
                                            onTap: () {
                                              // Clear file if format type changes
                                              final newIsPdf = _pdfDocCodes
                                                  .contains(t.code);
                                              final curIsPdf =
                                                  _selectedType != null &&
                                                  _pdfDocCodes.contains(
                                                    _selectedType!.code,
                                                  );
                                              setState(() {
                                                _selectedType = t;
                                                if (newIsPdf != curIsPdf) {
                                                  _file = null;
                                                  _filePdf = false;
                                                }
                                              });
                                            },
                                          ),
                                        )
                                        .toList(),
                                  );
                                },
                              ),

                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _isUploading || isApproved
                                      ? null
                                      : _handleUpload,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isApproved
                                        ? const Color(0xFF059669)
                                        : AppColors.primaryDarkGreen,
                                    disabledBackgroundColor: isApproved
                                        ? const Color(
                                            0xFF059669,
                                          ).withValues(alpha: 0.5)
                                        : null,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isUploading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isApproved) ...[
                                              const Icon(
                                                Icons.lock_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Text(
                                              isApproved
                                                  ? 'Dokumen Disetujui'
                                                  : 'Unggah Dokumen',
                                              style: tt.labelLarge?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CV template (bundled asset, type code `cv`)
// ─────────────────────────────────────────────────────────────────────────────

class _CvTemplateBanner extends StatelessWidget {
  const _CvTemplateBanner({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contoh format CV',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buka template resmi untuk diisi, lalu unggah sebagai PDF di bawah.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Lihat template',
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondaryLightGreen
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryDarkGreen : cs.outlineVariant,
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
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0369A1),
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

// ─────────────────────────────────────────────────────────────────────────────
// Format hint chip
// ─────────────────────────────────────────────────────────────────────────────

class _FormatHintChip extends StatelessWidget {
  const _FormatHintChip({required this.isPdf});
  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (Color bg, Color fg, IconData icon, String label) = isPdf
        ? (
            const Color(0xFFFEF3C7),
            const Color(0xFF92400E),
            Icons.picture_as_pdf_rounded,
            'Format: PDF — maks. 2 MB',
          )
        : (
            const Color(0xFFDBEAFE),
            const Color(0xFF1D4ED8),
            Icons.image_outlined,
            'Format: JPG / PNG — maks. 500 KB',
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File placeholder (empty state inside picker box)
// ─────────────────────────────────────────────────────────────────────────────

class _FilePlaceholder extends StatelessWidget {
  const _FilePlaceholder({
    required this.isPdf,
    required this.tt,
    required this.cs,
  });
  final bool isPdf;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondaryLightGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
            size: 32,
            color: AppColors.primaryDarkGreen,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isPdf ? 'Ketuk untuk pilih PDF' : 'Ketuk untuk buka galeri',
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDarkGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isPdf ? 'PDF — maks. 2 MB' : 'JPG, PNG — maks. 500 KB',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (!isPdf) ...[
          const SizedBox(height: 2),
          Text(
            'Ikon kamera di kanan atas untuk foto langsung',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF preview widget
// ─────────────────────────────────────────────────────────────────────────────

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final fileName = file.path.split('/').last;
    final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF92400E),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fileName,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$sizeKb KB',
                  style: tt.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primaryDarkGreen,
            size: 20,
          ),
        ],
      ),
    );
  }
}
