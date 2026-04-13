import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../config/colors.dart';
import '../../../../core/models/region.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/widgets/ktp_camera_screen.dart';
import '../../../../core/widgets/professional_text_field.dart';
import '../../../../core/widgets/professional_dropdown_field.dart';
import '../../../../core/widgets/professional/professional_button.dart';
import '../../../../core/widgets/professional/professional_gradient_background.dart';
import '../../../../core/widgets/professional/professional_card.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/regions_provider.dart';
import '../../domain/models/ktp_data.dart';
import '../providers/social_complete_provider.dart';

/// Profile completion page shown after social login (Google/Apple)
/// when the backend returns needs_registration=true.
///
/// Flow: Upload KTP → OCR extracts data → user verifies/fills
/// Name, NIK, Tempat Lahir, Tanggal Lahir → submit → go to /home.
class SocialCompleteProfilePage extends ConsumerStatefulWidget {
  const SocialCompleteProfilePage({super.key});

  @override
  ConsumerState<SocialCompleteProfilePage> createState() =>
      _SocialCompleteProfilePageState();
}

class _SocialCompleteProfilePageState
    extends ConsumerState<SocialCompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nikCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  final _nikFocus = FocusNode();
  final _nameFocus = FocusNode();

  Region? _selectedCity;
  DateTime? _selectedDate;
  String? _ocrBirthPlace;

  bool _isPickingImage = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(regenciesProvider);
      final ktpData = ref.read(socialCompleteProvider).ktpData;
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

  // ── Image picking ──────────────────────────────────────────────────────────

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
                    child: Icon(Icons.camera_alt,
                        color: colors.onPrimaryContainer, size: 20),
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
      setState(() => _isPickingImage = false);
      _clearFields();
      ref.read(socialCompleteProvider.notifier).setKtpImage(imageFile);
      await _runOcr();
    } on PlatformException catch (e) {
      if (!mounted) return;
      CustomToast.show(context,
          message: 'Izin ditolak: ${e.message}', type: ToastType.error);
    } catch (_) {
      if (!mounted) return;
      CustomToast.show(context,
          message: 'Gagal memproses gambar', type: ToastType.error);
    } finally {
      if (mounted && _isPickingImage) setState(() => _isPickingImage = false);
    }
  }

  Future<File?> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!mounted) return null;
      if (status.isDenied ||
          status.isPermanentlyDenied ||
          status.isRestricted) {
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
    return picked == null ? null : File(picked.path);
  }

  // ── OCR ─────────────────────────────────────────────────────────────────────

  Future<void> _runOcr() async {
    try {
      await ref.read(socialCompleteProvider.notifier).processOcr();
      if (!mounted) return;
      final data = ref.read(socialCompleteProvider).ktpData;
      if (data != null && data.hasData) {
        _populateFields(data);
        CustomToast.show(context,
            message: 'Data KTP berhasil diekstrak! Periksa dan lengkapi.',
            type: ToastType.success);
      } else {
        CustomToast.show(context,
            message:
                'OCR selesai, tapi tidak ada data terdeteksi. Silakan isi manual.',
            type: ToastType.info);
      }
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context,
          message: 'Gagal memproses OCR: ${_extractMessage(e)}',
          type: ToastType.error);
    }
  }

  void _populateFields(KtpData data) {
    setState(() {
      if (data.nik != null) _nikCtrl.text = data.nik!;
      if (data.name != null) _nameCtrl.text = data.name!.toUpperCase();
      if (data.birthPlace != null) _ocrBirthPlace = data.birthPlace;
      if (data.birthDate != null) _parseAndSetDate(data.birthDate!);
    });
    if (data.birthPlace != null || data.birthPlaceRegency != null) {
      unawaited(_resolveBirthPlaceFromKtp(data));
    }
  }

  Future<void> _resolveBirthPlaceFromKtp(KtpData data) async {
    final cities = await _loadRegenciesWithRetry();
    if (!mounted || cities == null) return;

    if (data.birthPlaceRegency != null) {
      final regency = data.birthPlaceRegency!;
      final match = cities.where((c) => c.id == regency.id).firstOrNull;
      if (match != null) {
        setState(() {
          _selectedCity = match;
          _birthPlaceCtrl.text = match.name;
        });
        return;
      }
      if (data.birthPlace != null) {
        _applyTryMatchCity(data.birthPlace!, cities);
      } else if (_ocrBirthPlace != null) {
        _applyTryMatchCity(_ocrBirthPlace!, cities);
      }
    } else if (data.birthPlace != null) {
      _applyTryMatchCity(data.birthPlace!, cities);
    }
  }

  Future<List<Region>?> _loadRegenciesWithRetry() async {
    try {
      return await ref.read(regenciesProvider.future);
    } catch (_) {
      ref.invalidate(regenciesProvider);
      try {
        return await ref.read(regenciesProvider.future);
      } catch (_) {
        return null;
      }
    }
  }

  // ── City matching ──────────────────────────────────────────────────────────

  String _normalizePlace(String s) {
    return s
        .toUpperCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\bKAB\.?\b'), 'KABUPATEN')
        .replaceAll(RegExp(r'\bKT\.?\b'), 'KOTA')
        .replaceAll('.', '')
        .trim();
  }

  String _stripRegencyPrefix(String s) {
    return s
        .replaceFirst(RegExp(r'^KABUPATEN\s+'), '')
        .replaceFirst(RegExp(r'^KOTA\s+'), '')
        .trim();
  }

  void _applyTryMatchCity(String birthPlace, List<Region> cities) {
    final query = _normalizePlace(birthPlace);
    if (query.isEmpty) return;
    Region? match;

    for (final c in cities) {
      if (_normalizePlace(c.name) == query) {
        match = c;
        break;
      }
    }
    if (match == null) {
      final qs = _stripRegencyPrefix(query);
      if (qs.isNotEmpty) {
        for (final c in cities) {
          if (_stripRegencyPrefix(_normalizePlace(c.name)) == qs) {
            match = c;
            break;
          }
        }
      }
    }
    if (match == null) {
      for (final c in cities) {
        final cn = _normalizePlace(c.name);
        if (cn.contains(query) || query.contains(cn)) {
          match = c;
          break;
        }
      }
    }
    if (match == null) {
      final qs = _stripRegencyPrefix(query);
      if (qs.length >= 3) {
        for (final c in cities) {
          final cn = _stripRegencyPrefix(_normalizePlace(c.name));
          if (cn.contains(qs) || qs.contains(cn)) {
            match = c;
            break;
          }
        }
      }
    }

    if (match != null && mounted) {
      setState(() {
        _selectedCity = match;
        _birthPlaceCtrl.text = match!.name;
      });
    }
  }

  void _parseAndSetDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final d = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        _selectedDate = DateTime(y, m, d);
        _birthDateCtrl.text = _formattedDate;
      }
    } catch (_) {}
  }

  void _clearFields() {
    setState(() {
      _nikCtrl.clear();
      _nameCtrl.clear();
      _birthPlaceCtrl.clear();
      _birthDateCtrl.clear();
      _selectedCity = null;
      _selectedDate = null;
      _ocrBirthPlace = null;
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

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
          return 'Tidak dapat terhubung ke server.';
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
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: AppColors.primaryDarkGreen,
            headerForegroundColor: Colors.white,
            dayStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
            weekdayStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600, color: AppColors.textMedium),
            yearStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
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

  Future<void> _showCityPicker() async {
    final cities = await _loadRegenciesWithRetry();
    if (!mounted) return;
    if (cities == null || cities.isEmpty) {
      CustomToast.show(context,
          message: 'Gagal memuat daftar kota/kabupaten.',
          type: ToastType.error);
      return;
    }
    final result = await showModalBottomSheet<Region>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(
        cities: cities,
        initialSearch: _ocrBirthPlace ?? _selectedCity?.name ?? '',
        selected: _selectedCity,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedCity = result;
        _birthPlaceCtrl.text = result.name;
      });
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate != null) {
      final now = DateTime.now();
      int age = now.year - _selectedDate!.year;
      if (now.month < _selectedDate!.month ||
          (now.month == _selectedDate!.month &&
              now.day < _selectedDate!.day)) {
        age--;
      }
      if (age < 18) {
        CustomToast.show(context,
            message: 'Usia Anda kurang dari 18 tahun.',
            type: ToastType.error);
        return;
      }
      if (age > 45) {
        CustomToast.show(context,
            message: 'Usia Anda lebih dari 45 tahun.',
            type: ToastType.error);
        return;
      }
    }

    final birthDateIso = _selectedDate != null
        ? '${_selectedDate!.year.toString().padLeft(4, '0')}-'
            '${_selectedDate!.month.toString().padLeft(2, '0')}-'
            '${_selectedDate!.day.toString().padLeft(2, '0')}'
        : null;

    try {
      setState(() => _isSubmitting = true);

      final user = await ref
          .read(socialCompleteProvider.notifier)
          .completeProfile(
            nik: _nikCtrl.text.trim(),
            fullName: _nameCtrl.text.trim(),
            birthPlaceId: _selectedCity?.id,
            birthDateIso: birthDateIso,
          );

      if (!mounted) return;

      ref.read(socialCompleteProvider.notifier).reset();
      ref.read(authStateProvider.notifier).setAuthenticatedUser(user);

      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      CustomToast.show(context,
          message: 'Gagal menyimpan profil: ${_extractMessage(e)}',
          type: ToastType.error);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(socialCompleteProvider);
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ProfessionalGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset + 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height - 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Header
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.badge_outlined,
                              size: 40, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Lengkapi Profil',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload KTP dan lengkapi data diri untuk melanjutkan',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Form card
                    ProfessionalCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // KTP upload
                              _KtpUploadCard(
                                ktpImage: state.ktpImage,
                                isPickingImage: _isPickingImage,
                                onTap:
                                    _isPickingImage ? null : _showImageSourceSheet,
                              ),

                              if (state.isProcessing && !_isSubmitting) ...[
                                const SizedBox(height: 12),
                                _OcrProgressBanner(),
                              ],

                              const SizedBox(height: 24),

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
                                'Periksa dan lengkapi data diri sesuai KTP',
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
                                  if (v == null || v.isEmpty) {
                                    return 'NIK wajib diisi';
                                  }
                                  if (v.length != 16) {
                                    return 'NIK harus 16 digit';
                                  }
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
                                textCapitalization:
                                    TextCapitalization.characters,
                                upperCase: true,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Nama wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Tempat Lahir
                              ProfessionalDropdownField(
                                controller: _birthPlaceCtrl,
                                label: 'Tempat Lahir',
                                hint: 'Pilih kota/kabupaten',
                                prefixIcon: Icons.location_on_outlined,
                                onTap: _showCityPicker,
                                validator: (_) => _selectedCity == null
                                    ? 'Tempat lahir wajib dipilih'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Tanggal Lahir
                              ProfessionalDropdownField(
                                controller: _birthDateCtrl,
                                label: 'Tanggal Lahir',
                                hint: 'Pilih tanggal lahir',
                                prefixIcon: Icons.calendar_today_outlined,
                                onTap: _selectDate,
                                validator: (_) => _selectedDate == null
                                    ? 'Tanggal lahir wajib dipilih'
                                    : null,
                              ),
                              const SizedBox(height: 28),

                              // Submit
                              ProfessionalButton(
                                label: 'Simpan & Lanjutkan',
                                onPressed:
                                    (state.isProcessing || _isSubmitting)
                                        ? null
                                        : _handleSubmit,
                                isLoading: _isSubmitting,
                                icon: Icons.check_circle_outline_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── KTP upload card ──────────────────────────────────────────────────────────

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

// ── OCR progress banner ──────────────────────────────────────────────────────

class _OcrProgressBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: cs.onTertiaryContainer),
          ),
          const SizedBox(width: 12),
          Text(
            'Memproses OCR dari foto KTP...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ── City picker bottom sheet ─────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  final List<Region> cities;
  final String initialSearch;
  final Region? selected;

  const _CityPickerSheet({
    required this.cities,
    required this.initialSearch,
    required this.selected,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  late final TextEditingController _searchCtrl;
  late List<Region> _filtered;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialSearch);
    _filtered = _applyFilter(widget.initialSearch);
    _searchCtrl.addListener(() {
      setState(() => _filtered = _applyFilter(_searchCtrl.text));
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Region> _applyFilter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return widget.cities;
    return widget.cities
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Pilih Kota / Kabupaten',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMedium),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Cari kota atau kabupaten...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: AppColors.textLight),
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.textMedium, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: AppColors.textMedium, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundOffWhite,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.primaryDarkGreen, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filtered.length} kota/kabupaten',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final city = _filtered[i];
                    final isSelected = widget.selected?.id == city.id;
                    return ListTile(
                      onTap: () => Navigator.pop(context, city),
                      selected: isSelected,
                      selectedTileColor:
                          AppColors.primaryDarkGreen.withValues(alpha: 0.1),
                      tileColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 2),
                      title: Text(
                        city.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primaryDarkGreen
                              : AppColors.textDark,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded,
                              color: AppColors.primaryDarkGreen, size: 20)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
