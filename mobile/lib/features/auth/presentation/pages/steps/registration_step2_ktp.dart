import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../core/models/region.dart';
import '../../../../../core/widgets/custom_toast.dart';
import '../../../../../core/widgets/ktp_camera_screen.dart';
import '../../../../../core/widgets/m3_text_field.dart';
import '../../../data/providers/regions_provider.dart';
import '../../../domain/models/ktp_data.dart';
import '../../providers/registration_provider.dart';

/// Step 2 of registration: upload KTP photo, auto-extract OCR data,
/// let the user verify / complete the form, then submit.
///
/// Performance note: [M3TextField] derives all styles from [Theme], avoiding
/// per-keystroke [TextStyle] allocations. [regenciesProvider] is not watched in
/// [build] so loading the full regency list does not rebuild this widget on
/// every frame; birth-place resolution awaits the provider when needed.
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

  // Structured picker state
  Region? _selectedCity;
  DateTime? _selectedDate;

  /// Raw OCR city name  used to pre-fill the city search query.
  String? _ocrBirthPlace;

  bool _isPickingImage = false;
  bool _isRegistering = false;

  bool _dataDeclarationChecked = false;
  bool _zeroCostChecked = false;

  //  Lifecycle 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Warm up city data without subscribing (no rebuilds when it loads).
      ref.read(regenciesProvider);
      // Restore OCR data if available.
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
      setState(() => _isPickingImage = false);
      _clearFields();
      ref.read(registrationProvider.notifier).setKtpImage(imageFile);
      await _runOcr();
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

  Future<File?> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!mounted) return null;
      if (status.isDenied || status.isPermanentlyDenied) {
        CustomToast.show(context,
            message: 'Izin kamera diperlukan untuk mengambil foto',
            type: ToastType.error);
        if (status.isPermanentlyDenied) await openAppSettings();
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

  //  OCR 

  Future<void> _runOcr() async {
    try {
      await ref.read(registrationProvider.notifier).processOcr();
      if (!mounted) return;
      final data = ref.read(registrationProvider).ktpData;
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

  /// Loads regencies then applies OCR/backend birth place — avoids [whenData]
  /// silently doing nothing while [regenciesProvider] is still loading.
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

  /// Fetches all regencies; on failure invalidates once and retries (helps
  /// after transient errors so Riverpod does not stay stuck on AsyncError).
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

  //  City matching helpers

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
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final initial = _selectedDate ?? DateTime(1990);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: cs.primary),
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
    if (cities == null) {
      CustomToast.show(context,
          message:
              'Gagal memuat daftar kota/kabupaten. Periksa koneksi internet lalu coba lagi.',
          type: ToastType.error);
      return;
    }
    if (cities.isEmpty) {
      CustomToast.show(context,
          message:
              'Daftar wilayah kosong di server. Hubungi administrator atau coba lagi nanti.',
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

  //  Registration 

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_dataDeclarationChecked || !_zeroCostChecked) {
      CustomToast.show(
        context,
        message:
            'Anda harus menyetujui pernyataan data benar dan memahami skema zero cost sebelum melanjutkan.',
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

    ref.read(registrationProvider.notifier).updateKtpData(KtpData(
          nik: _nikCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          birthPlace: _selectedCity?.name ?? '',
          birthDate: _formattedDate,
        ));

    // Save the confirmed region ID and ISO date so the backend can persist them.
    ref.read(registrationProvider.notifier).setBirthInfo(
      birthPlaceId: _selectedCity?.id,
      birthDateIso: _selectedDate != null
          ? '${_selectedDate!.year.toString().padLeft(4, '0')}-'
            '${_selectedDate!.month.toString().padLeft(2, '0')}-'
            '${_selectedDate!.day.toString().padLeft(2, '0')}'
          : null,
    );

    ref.read(registrationProvider.notifier).setDeclarations(
          dataDeclarationConfirmed: _dataDeclarationChecked,
          zeroCostUnderstood: _zeroCostChecked,
        );

    final email = ref.read(registrationProvider).email;

    try {
      setState(() => _isRegistering = true);

      await ref
          .read(registrationProvider.notifier)
          .completeRegistration();

      if (!mounted) return;

      ref.read(registrationProvider.notifier).reset();

      // Email registration — do NOT set authenticated user yet.
      // Auth tokens are stored; the user must verify email first.
      if (mounted && email != null) {
        context.go('/email-verification?email=${Uri.encodeComponent(email)}');
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
    // Read state without watching regencies  prefetch is done in initState.
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Langkah 2 dari 2  Upload KTP dan lengkapi data diri',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          //  KTP upload card 
          _KtpUploadCard(
            ktpImage: state.ktpImage,
            isPickingImage: _isPickingImage,
            onTap: _isPickingImage ? null : _showImageSourceSheet,
          ),

          //  OCR progress banner 
          if (state.isProcessing && !_isRegistering) ...[
            const SizedBox(height: 12),
            _OcrProgressBanner(),
          ],

          const SizedBox(height: 24),

          //  Data fields 
          Text(
            'Data Diri',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Periksa dan lengkapi data diri sesuai KTP',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // NIK
          M3TextField(
            controller: _nikCtrl,
            focusNode: _nikFocus,
            nextFocusNode: _nameFocus,
            label: 'NIK',
            hint: '16 digit angka',
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return 'NIK wajib diisi';
              if (v.length != 16) return 'NIK harus 16 digit';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Nama Lengkap
          M3TextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            label: 'Nama Lengkap',
            hint: 'Sesuai KTP',
            prefixIcon: Icons.person_outline_rounded,
            upperCase: true,
            textInputAction: TextInputAction.done,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
          const SizedBox(height: 16),

          // Tempat Lahir  city picker
          M3TextField(
            controller: _birthPlaceCtrl,
            label: 'Tempat Lahir',
            hint: 'Pilih kota/kabupaten',
            prefixIcon: Icons.location_on_outlined,
            readOnly: true,
            onTap: _showCityPicker,
            suffixWidget: Icon(Icons.arrow_drop_down_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            validator: (_) =>
                _selectedCity == null ? 'Tempat lahir wajib dipilih' : null,
          ),
          const SizedBox(height: 16),

          // Tanggal Lahir  date picker
          M3TextField(
            controller: _birthDateCtrl,
            label: 'Tanggal Lahir',
            hint: 'Pilih tanggal lahir',
            prefixIcon: Icons.calendar_today_outlined,
            readOnly: true,
            onTap: _selectDate,
            suffixWidget: Icon(Icons.arrow_drop_down_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                                  _showTermsAndPrivacyModal(context);
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
                                  _showTermsAndPrivacyModal(context);
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
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _zeroCostChecked,
                      onChanged: (v) {
                        setState(() {
                          _zeroCostChecked = v ?? false;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Saya telah membaca dan memahami bahwa proses penempatan kerja menggunakan skema zero cost, '
                        'di mana seluruh biaya proses resmi ditanggung oleh perusahaan sesuai ketentuan yang berlaku.',
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

          //  Register button (after agreements)
          FilledButton(
            onPressed: (state.isProcessing || _isRegistering)
                ? null
                : _handleRegister,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isRegistering
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.onPrimary),
                  )
                : Text(
                    'Daftar Sekarang',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

void _showTermsAndPrivacyModal(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Syarat & Ketentuan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Harap baca dengan saksama sebelum melanjutkan pendaftaran.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Syarat & Ketentuan',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Data yang Anda isi harus sesuai dengan dokumen resmi (KTP, KK, ijazah, dan dokumen pendukung lainnya) dan dapat dipertanggungjawabkan.\n'
                          '• Anda memberikan izin kepada perusahaan untuk menggunakan data ini dalam proses rekrutmen, pengolahan dokumen penempatan, dan pelaporan kepada instansi terkait.\n'
                          '• Apabila di kemudian hari ditemukan ketidaksesuaian atau pemalsuan data, perusahaan berhak membatalkan proses penempatan dan/atau melakukan tindakan lain sesuai ketentuan yang berlaku.\n'
                          '• Ketentuan lebih rinci mengenai proses penempatan kerja akan dijelaskan oleh petugas perusahaan dan/atau tercantum dalam dokumen perjanjian terpisah.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '2. Kebijakan Privasi',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Data pribadi Anda akan disimpan dan diproses sesuai dengan ketentuan perlindungan data pribadi yang berlaku.\n'
                          '• Data hanya akan digunakan untuk keperluan proses rekrutmen, penempatan kerja, pemenuhan kewajiban hukum, dan peningkatan layanan perusahaan.\n'
                          '• Perusahaan tidak akan menjual atau membagikan data pribadi Anda kepada pihak ketiga yang tidak berkepentingan, kecuali diwajibkan oleh peraturan perundang-undangan atau dengan persetujuan Anda.\n'
                          '• Anda berhak mengajukan permintaan koreksi, pembaruan, atau penghapusan data sesuai dengan prosedur internal perusahaan dan ketentuan hukum yang berlaku.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Dengan melanjutkan proses pendaftaran, Anda menyatakan telah membaca, memahami, dan menyetujui Syarat & Ketentuan serta Kebijakan Privasi ini.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
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

//  OCR progress banner 

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

//  City picker bottom sheet 

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
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
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
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search field
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Cari kota atau kabupaten...',
                    prefixIcon:
                        Icon(Icons.search, color: cs.onSurfaceVariant, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: cs.onSurfaceVariant, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    // Relies on InputDecorationTheme for fill + borders
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Results count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filtered.length} kota/kabupaten',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const Divider(height: 1),

              // City list
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
                      selectedTileColor: cs.primaryContainer,
                      tileColor: Colors.transparent,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      title: Text(
                        city.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded,
                              color: cs.primary, size: 20)
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
