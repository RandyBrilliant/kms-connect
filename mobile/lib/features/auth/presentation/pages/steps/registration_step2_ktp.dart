import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../config/colors.dart';
import '../../../../../core/widgets/terms_privacy_modal.dart';
import '../../../../../core/widgets/custom_toast.dart';
import '../../../../../core/widgets/ktp_camera_screen.dart';
import '../../../../../core/widgets/ktp_gallery_crop_screen.dart';
import '../../../../../core/widgets/professional_text_field.dart';
import '../../../../../core/widgets/professional_dropdown_field.dart';
import '../../../../../core/widgets/professional/professional_button.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../domain/models/ktp_data.dart';
import '../../../../notifications/data/services/notification_service.dart';
import '../../../../profile/data/providers/profile_provider.dart';
import '../../providers/registration_provider.dart';

/// Step 2 of registration: upload KTP photo and enter identity fields manually.
///
/// Performance note: [ProfessionalTextField] derives styles from [Theme].
class RegistrationStep2Ktp extends ConsumerStatefulWidget {
  const RegistrationStep2Ktp({super.key});

  @override
  ConsumerState<RegistrationStep2Ktp> createState() =>
      _RegistrationStep2KtpState();
}

class _RegistrationStep2KtpState extends ConsumerState<RegistrationStep2Ktp> {
  final _formKey = GlobalKey<FormState>();

  // Text field controllers
  final _nikCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  // Focus nodes
  final _nikFocus = FocusNode();
  final _nameFocus = FocusNode();

  DateTime? _selectedDate;

  bool _isPickingImage = false;
  bool _isRegistering = false;

  bool _dataDeclarationChecked = false;

  //  Lifecycle 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ktpData = ref.read(registrationProvider).ktpData;
      if (ktpData != null) _populateFields(ktpData);
    });
  }

  @override
  void dispose() {
    _nikCtrl.dispose();
    _nameCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _birthDateCtrl.dispose();
    _nikFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  //  Image picking 

  Future<void> _showImageSourceSheet() async {
    if (_isPickingImage) return;
    final cs = Theme.of(context).colorScheme;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    child:
                        Icon(Icons.camera_alt, color: colors.onPrimaryContainer, size: 20),
                  ),
                  title: Text('Kamera',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.secondaryContainer,
                    child: Icon(Icons.photo_library,
                        color: colors.onSecondaryContainer, size: 20),
                  ),
                  title: Text('Galeri',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (source != null) await _pickAndProcessImage(source);
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final imageFile = await _pickImage(source);
      if (imageFile == null || !mounted) return;
      final persistentFile = await _persistKtpImage(imageFile);
      setState(() => _isPickingImage = false);
      _clearFields();
      ref.read(registrationProvider.notifier).setKtpImage(persistentFile);
      // OCR disabled — user fills all fields manually.
      // await _runOcr();
    } on PlatformException catch (e) {
      if (!mounted) return;
      CustomToast.show(context,
          message: 'Izin ditolak: ${e.message}', type: ToastType.error);
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context,
          message: 'Gagal memproses gambar', type: ToastType.error);
    } finally {
      if (mounted && _isPickingImage) setState(() => _isPickingImage = false);
    }
  }

  Future<File> _persistKtpImage(File source) async {
    final appDir = await getApplicationSupportDirectory();
    final ktpDir = Directory(p.join(appDir.path, 'ktp_uploads'));
    if (!await ktpDir.exists()) {
      await ktpDir.create(recursive: true);
    }
    final ext = p.extension(source.path).toLowerCase();
    final safeExt = switch (ext) {
      '.jpg' || '.jpeg' || '.png' || '.webp' => ext,
      _ => '.jpg',
    };
    final targetPath = p.join(
      ktpDir.path,
      'ktp_${DateTime.now().millisecondsSinceEpoch}$safeExt',
    );
    return source.copy(targetPath);
  }

  Future<File?> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!mounted) return null;
      if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
        CustomToast.show(context,
            message: 'Izin kamera diperlukan untuk mengambil foto',
            type: ToastType.error);
        if (status.isPermanentlyDenied || status.isRestricted) {
          await openAppSettings();
        }
        return null;
      }
      return Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (_) => const KtpCameraScreen()),
      );
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080);
    if (picked == null) return null;
    return _cropGalleryImageToKtpGuide(File(picked.path));
  }

  Future<File?> _cropGalleryImageToKtpGuide(File sourceFile) async {
    try {
      final cropped = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (_) => KtpGalleryCropScreen(sourceFile: sourceFile),
        ),
      );
      return cropped;
    } catch (_) {
      if (!mounted) return sourceFile;
      CustomToast.show(
        context,
        message: 'Gagal menyesuaikan rasio foto KTP',
        type: ToastType.info,
      );
      return sourceFile;
    }
  }

  // OCR disabled for registration — re-enable by uncommenting _runOcr() after upload.
  //
  // Future<void> _runOcr() async {
  //   try {
  //     await ref.read(registrationProvider.notifier).processOcr();
  //     if (!mounted) return;
  //     final data = ref.read(registrationProvider).ktpData;
  //     if (data != null && data.hasData) {
  //       _populateFields(data);
  //       CustomToast.show(context,
  //           message:
  //               'NIK terisi dari foto KTP. Isi nama, tempat lahir, dan tanggal lahir sesuai KTP.',
  //           type: ToastType.success);
  //     } else {
  //       CustomToast.show(context,
  //           message:
  //               'OCR selesai, tapi tidak ada data terdeteksi. Silakan isi manual.',
  //           type: ToastType.info);
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     CustomToast.show(context,
  //         message: 'Gagal memproses OCR: ${_extractMessage(e)}',
  //         type: ToastType.error);
  //   }
  // }

  void _populateFields(KtpData data) {
    setState(() {
      // OCR preview returns NIK only; other fields are manual per policy.
      if (data.nik != null) _nikCtrl.text = data.nik!;
    });
  }

  void _clearFields() {
    setState(() {
      _nikCtrl.clear();
      _nameCtrl.clear();
      _birthPlaceCtrl.clear();
      _birthDateCtrl.clear();
      _selectedDate = null;
    });
  }

  //  Error message helper (unchanged logic) 

  String _extractMessage(Object e) {
    if (e is DioException) {
      final msg = e.message;
      if (msg != null && msg.isNotEmpty) return msg;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'] as String?;
        if (detail != null && detail.isNotEmpty) return detail;
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return errors.entries.map((entry) {
            final v = entry.value;
            if (v is List && v.isNotEmpty) return v.first.toString();
            return v.toString();
          }).join('\n');
        }
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Koneksi timeout. Periksa jaringan Anda.';
        case DioExceptionType.connectionError:
          return 'Tidak dapat terhubung ke server. Periksa jaringan Anda.';
        default:
          return 'Terjadi kesalahan. Silakan coba lagi.';
      }
    }
    final raw = e.toString();
    final colonIdx = raw.lastIndexOf(': ');
    if (colonIdx != -1 && colonIdx + 2 < raw.length) {
      return raw.substring(colonIdx + 2);
    }
    return raw;
  }

  //  Picker helpers 

  String get _formattedDate {
    if (_selectedDate == null) return '';
    final d = _selectedDate!;
    return '${d.day.toString().padLeft(2, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.year}';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? DateTime(1990);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primaryDarkGreen,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textDark,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: AppColors.primaryDarkGreen,
            headerForegroundColor: Colors.white,
            dayStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
            ),
            weekdayStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
            yearStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _birthDateCtrl.text = _formattedDate;
      });
    }
  }

  //  Registration 

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_dataDeclarationChecked) {
      CustomToast.show(
        context,
        message: 'Anda harus menyetujui pernyataan data benar sebelum melanjutkan.',
        type: ToastType.error,
      );
      return;
    }

    // Validasi usia: minimal 18 tahun, maksimal 45 tahun
    if (_selectedDate != null) {
      final now = DateTime.now();
      int age = now.year - _selectedDate!.year;
      if (now.month < _selectedDate!.month ||
          (now.month == _selectedDate!.month && now.day < _selectedDate!.day)) {
        age--;
      }
      if (age < 18) {
        CustomToast.show(context,
            message:
                'Usia Anda kurang dari 18 tahun. Anda tidak memenuhi syarat untuk mendaftar.',
            type: ToastType.error);
        return;
      }
      if (age > 45) {
        CustomToast.show(context,
            message:
                'Usia Anda lebih dari 45 tahun. Anda tidak memenuhi syarat untuk mendaftar.',
            type: ToastType.error);
        return;
      }
    }

    final selectedKtpFile = ref.read(registrationProvider).ktpImage;
    if (selectedKtpFile == null || !await selectedKtpFile.exists()) {
      CustomToast.show(
        context,
        message: 'File KTP tidak ditemukan. Silakan upload ulang foto KTP.',
        type: ToastType.error,
      );
      return;
    }

    ref.read(registrationProvider.notifier).updateKtpData(KtpData(
          nik: _nikCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          birthPlace: _birthPlaceCtrl.text.trim(),
          birthDate: _formattedDate,
        ));

    ref.read(registrationProvider.notifier).setBirthInfo(
      birthPlaceText: _birthPlaceCtrl.text.trim().toUpperCase(),
      birthDateIso: _selectedDate != null
          ? '${_selectedDate!.year.toString().padLeft(4, '0')}-'
            '${_selectedDate!.month.toString().padLeft(2, '0')}-'
            '${_selectedDate!.day.toString().padLeft(2, '0')}'
          : null,
    );

    ref.read(registrationProvider.notifier).setDeclarations(
          dataDeclarationConfirmed: _dataDeclarationChecked,
        );

    try {
      setState(() => _isRegistering = true);

      final authResponse = await ref
          .read(registrationProvider.notifier)
          .completeRegistration();

      if (!mounted) return;

      ref
          .read(authStateProvider.notifier)
          .setAuthenticatedUser(authResponse.user);
      NotificationService().registerToken();
      await ref
          .read(profileNotifierProvider.notifier)
          .loadProfile(force: true);

      ref.read(registrationProvider.notifier).reset();

      if (mounted) {
        context.go('/profile/complete');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegistering = false);
      CustomToast.show(context,
          message: 'Gagal registrasi: ${_extractMessage(e)}',
          type: ToastType.error);
    }
  }

  //  Build 

  @override
  Widget build(BuildContext context) {
    // Registration wizard state.
    final state = ref.watch(registrationProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          //  Section label 
          const SizedBox(height: 20),
          Text(
            'Verifikasi Identitas',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Langkah 2 dari 2 • Upload KTP dan lengkapi data diri',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          //  KTP upload card 
          _KtpUploadCard(
            ktpImage: state.ktpImage,
            isPickingImage: _isPickingImage,
            onTap: _isPickingImage ? null : _showImageSourceSheet,
          ),

          const SizedBox(height: 24),

          // Data fields section
          Text(
            'Data Diri',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lengkapi NIK, nama, tempat lahir, dan tanggal lahir sesuai KTP.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 16),

          // NIK
          ProfessionalTextField(
            controller: _nikCtrl,
            focusNode: _nikFocus,
            label: 'NIK',
            hintText: '16 digit angka',
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            onSubmitted: (_) => _nameFocus.requestFocus(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'NIK wajib diisi';
              if (v.length != 16) return 'NIK harus 16 digit';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Nama Lengkap
          ProfessionalTextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            label: 'Nama Lengkap',
            hintText: 'Sesuai KTP',
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            upperCase: true,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
          const SizedBox(height: 16),

          ProfessionalTextField(
            controller: _birthPlaceCtrl,
            label: 'Tempat Lahir',
            hintText: 'Sesuai KTP',
            prefixIcon: Icons.location_on_outlined,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.characters,
            upperCase: true,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Tempat lahir wajib diisi' : null,
          ),
          const SizedBox(height: 16),

          // Tanggal Lahir – date picker
          ProfessionalDropdownField(
            controller: _birthDateCtrl,
            label: 'Tanggal Lahir',
            hint: 'Pilih tanggal lahir',
            prefixIcon: Icons.calendar_today_outlined,
            onTap: _selectDate,
            validator: (_) =>
                _selectedDate == null ? 'Tanggal lahir wajib dipilih' : null,
          ),
          const SizedBox(height: 24),

          //  Declarations (must agree before registering)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _dataDeclarationChecked,
                      onChanged: (v) {
                        setState(() {
                          _dataDeclarationChecked = v ?? false;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text:
                              'Saya menyatakan bahwa seluruh data yang saya isi adalah benar, sesuai dokumen asli, dan dapat dipertanggungjawabkan, serta saya telah membaca dan menyetujui ',
                          children: [
                            TextSpan(
                              text: 'Syarat & Ketentuan',
                              style: tt.bodySmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  showTermsAndPrivacyModal(context);
                                },
                            ),
                            TextSpan(
                              text: ' dan ',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: 'Kebijakan Privasi',
                              style: tt.bodySmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  showTermsAndPrivacyModal(context);
                                },
                            ),
                            TextSpan(
                              text: '.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Register button (after agreements)
          ProfessionalButton(
            label: 'Daftar Sekarang',
            onPressed: (state.isProcessing || _isRegistering)
                ? null
                : _handleRegister,
            isLoading: _isRegistering,
            icon: Icons.app_registration_rounded,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

//  KTP upload card 

class _KtpUploadCard extends StatelessWidget {
  final File? ktpImage;
  final bool isPickingImage;
  final VoidCallback? onTap;

  const _KtpUploadCard({
    required this.ktpImage,
    required this.isPickingImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImage = ktpImage != null;

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.586,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: hasImage ? Colors.black : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasImage ? cs.primary : cs.outlineVariant,
              width: hasImage ? 2 : 1.5,
            ),
          ),
          child: hasImage
              ? _KtpPreview(image: ktpImage!, onEdit: onTap)
              : _KtpPlaceholder(isLoading: isPickingImage),
        ),
      ),
    );
  }
}

class _KtpPreview extends StatelessWidget {
  final File image;
  final VoidCallback? onEdit;
  const _KtpPreview({required this.image, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(image, fit: BoxFit.cover, cacheWidth: 800),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.edit, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KtpPlaceholder extends StatelessWidget {
  final bool isLoading;
  const _KtpPlaceholder({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add_photo_alternate_outlined,
              size: 28, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: 12),
        Text(
          'Ketuk untuk upload foto KTP',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'Pastikan foto jelas dan terang',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// OCR progress banner — kept for when OCR is re-enabled.
//
// class _OcrProgressBanner extends StatelessWidget { ... }
