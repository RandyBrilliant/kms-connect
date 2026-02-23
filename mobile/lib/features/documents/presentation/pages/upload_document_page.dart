import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/document_provider.dart';
import '../../domain/models/document_type.dart';

class UploadDocumentPage extends ConsumerStatefulWidget {
  final int? documentTypeId;

  const UploadDocumentPage({super.key, this.documentTypeId});

  @override
  ConsumerState<UploadDocumentPage> createState() =>
      _UploadDocumentPageState();
}

class _UploadDocumentPageState extends ConsumerState<UploadDocumentPage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late final AnimationController _entranceCtrl;

  File? _selectedFile;
  int? _selectedTypeId;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedTypeId = widget.documentTypeId;
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Widget _animated(Widget child, double begin, double end) {
    final curve = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  }

  //  Pick from gallery 

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (file != null) setState(() => _selectedFile = File(file.path));
    } catch (e) {
      if (mounted) {
        CustomToast.show(context,
            message: 'Gagal membuka galeri', type: ToastType.error);
      }
    }
  }

  //  Pick from camera 

  Future<void> _pickFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (file != null) setState(() => _selectedFile = File(file.path));
    } catch (e) {
      if (mounted) {
        CustomToast.show(context,
            message: 'Gagal membuka kamera', type: ToastType.error);
      }
    }
  }

  //  Show source picker 

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Pilih Sumber Foto',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    color: const Color(0xFF6366F1),
                    bgColor: const Color(0xFFEEF2FF),
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromGallery();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: AppColors.primaryDarkGreen,
                    bgColor: AppColors.secondaryLightGreen,
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromCamera();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //  Upload handler 

  Future<void> _handleUpload() async {
    if (_selectedFile == null) {
      CustomToast.show(context,
          message: 'Pilih foto dokumen terlebih dahulu',
          type: ToastType.warning);
      return;
    }
    if (_selectedTypeId == null) {
      CustomToast.show(context,
          message: 'Pilih tipe dokumen terlebih dahulu',
          type: ToastType.warning);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.uploadDocument(
        documentTypeId: _selectedTypeId!,
        file: _selectedFile!,
      );
      if (!mounted) return;
      CustomToast.show(context,
          message: 'Dokumen berhasil diunggah', type: ToastType.success);
      ref.invalidate(myDocumentsProvider);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('DioException: ', '');
      CustomToast.show(context,
          message: msg.isNotEmpty ? msg : 'Gagal mengunggah dokumen',
          type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  //  Build 

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(documentTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Column(
          children: [
            _animated(_buildTopBar(), 0.0, 0.35),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type selector
                    _animated(
                      _buildTypeSelector(typesAsync),
                      0.15,
                      0.5,
                    ),
                    const SizedBox(height: 20),

                    // Image picker area
                    _animated(
                      _buildImagePicker(),
                      0.25,
                      0.6,
                    ),
                    const SizedBox(height: 16),

                    // Tips
                    _animated(
                      _buildTips(),
                      0.35,
                      0.7,
                    ),
                  ],
                ),
              ),
            ),

            // Upload button
            _animated(
              _buildUploadBar(),
              0.55,
              0.9,
            ),
          ],
        ),
      ),
    );
  }

  //  Top bar 

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: AppColors.backgroundOffWhite,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 22, color: Color(0xFF0F172A)),
            ),
          ),
          Expanded(
            child: Text(
              'Unggah Dokumen',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  //  Type selector 

  Widget _buildTypeSelector(AsyncValue<List<DocumentType>> typesAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondaryLightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_outlined,
                    size: 16, color: AppColors.primaryDarkGreen),
              ),
              const SizedBox(width: 10),
              Text(
                'Tipe Dokumen',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          typesAsync.when(
            loading: () => const LinearProgressIndicator(
              color: AppColors.primaryDarkGreen,
              backgroundColor: AppColors.backgroundOffWhite,
            ),
            error: (e, _) => Text('Gagal memuat tipe dokumen',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.error)),
            data: (types) => DropdownButtonFormField<int>(
              value: _selectedTypeId,
              hint: Text(
                'Pilih tipe dokumen',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5, color: AppColors.textLight),
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              items: types.map((t) {
                return DropdownMenuItem(
                  value: t.id,
                  child: Row(
                    children: [
                      Expanded(child: Text(t.name)),
                      if (t.isRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Wajib',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedTypeId = v),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: AppColors.backgroundOffWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primaryDarkGreen, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  Image picker area 

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto Dokumen',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showSourcePicker,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedFile != null
                    ? AppColors.primaryDarkGreen
                    : const Color(0xFFCBD5E1),
                width: _selectedFile != null ? 1.5 : 1,
                style: _selectedFile != null
                    ? BorderStyle.solid
                    : BorderStyle.solid,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: _selectedFile != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _selectedFile!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Change overlay
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_rounded,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Ganti Foto',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildPickerPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.secondaryLightGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_photo_alternate_outlined,
              size: 30, color: AppColors.primaryDarkGreen),
        ),
        const SizedBox(height: 14),
        Text(
          'Ketuk untuk memilih foto',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dari kamera atau galeri',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppColors.textMedium,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PickerChip(
                icon: Icons.photo_library_rounded, label: 'Galeri'),
            const SizedBox(width: 10),
            _PickerChip(icon: Icons.camera_alt_rounded, label: 'Kamera'),
          ],
        ),
      ],
    );
  }

  //  Tips 

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 16, color: Color(0xFF15803D)),
              const SizedBox(width: 6),
              Text(
                'Tips Upload Dokumen',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...[
            'Pastikan foto jelas, tidak buram, dan terbaca',
            'Seluruh isi dokumen terlihat penuh dalam frame',
            'Format yang diterima: JPG, PNG, PDF',
            'Ukuran file maksimal: 5MB',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded,
                      size: 13, color: Color(0xFF15803D)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF166534),
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

  //  Upload bar 

  Widget _buildUploadBar() {
    final ready = _selectedFile != null && _selectedTypeId != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isUploading || !ready) ? null : _handleUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDarkGreen,
              disabledBackgroundColor:
                  AppColors.primaryDarkGreen.withValues(alpha: 0.45),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    ready ? 'Unggah Dokumen' : 'Pilih dokumen & tipe terlebih dahulu',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// 
// _SourceOption
// 

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 
// _PickerChip
// 

class _PickerChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PickerChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundOffWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMedium),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}