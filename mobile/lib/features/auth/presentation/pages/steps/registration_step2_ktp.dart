import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../config/colors.dart';
import '../../../../../core/models/region.dart';
import '../../../../../core/widgets/custom_toast.dart';
import '../../../../../core/widgets/ktp_camera_screen.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/regions_provider.dart';
import '../../../domain/models/ktp_data.dart';
import '../../providers/registration_provider.dart';

/// Step 2 of registration: upload KTP photo, auto-extract OCR data,
/// let the user verify / complete the form, then register.
class RegistrationStep2Ktp extends ConsumerStatefulWidget {
  const RegistrationStep2Ktp({super.key});

  @override
  ConsumerState<RegistrationStep2Ktp> createState() =>
      _RegistrationStep2KtpState();
}

class _RegistrationStep2KtpState extends ConsumerState<RegistrationStep2Ktp> {
  final _formKey = GlobalKey<FormState>();

  // OCR-populated controllers
  final _nikController = TextEditingController();
  final _nameController = TextEditingController();

  // Structured pickers
  Region? _selectedCity;
  DateTime? _selectedDate;

  /// Raw OCR-returned city name  used to pre-fill the city search query.
  String? _ocrBirthPlace;

  bool _isPickingImage = false;
  bool _isRegistering = false;

  //  Lifecycle 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ktpData = ref.read(registrationProvider).ktpData;
      if (ktpData != null) _populateFields(ktpData);
    });
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  //  Image picking 

  Future<void> _showImageSourceSheet() async {
    if (_isPickingImage) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt,
                    color: AppColors.primaryDarkGreen),
                title: Text('Kamera',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: AppColors.primaryDarkGreen),
                title: Text('Galeri',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
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
      maxHeight: 1080,
    );
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
            message: 'OCR selesai, tapi tidak ada data terdeteksi. Silakan isi manual.',
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
      if (data.nik != null) _nikController.text = data.nik!;
      if (data.name != null) _nameController.text = data.name!;
      if (data.birthPlace != null) {
        _ocrBirthPlace = data.birthPlace;
        _tryMatchCity(data.birthPlace!);
      }
      if (data.birthDate != null) {
        _parseAndSetDate(data.birthDate!);
      }
    });
  }

  /// Normalise a place name for comparison:
  /// - uppercase, trim, collapse whitespace
  /// - expand common KTP abbreviations (KAB. → KABUPATEN, etc.)
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

  /// Strip the leading "KABUPATEN" or "KOTA" prefix so bare city names
  /// (e.g. "JAKARTA" from OCR) can match "KOTA JAKARTA PUSAT".
  String _stripRegencyPrefix(String s) {
    return s
        .replaceFirst(RegExp(r'^KABUPATEN\s+'), '')
        .replaceFirst(RegExp(r'^KOTA\s+'), '')
        .trim();
  }

  void _tryMatchCity(String birthPlace) {
    ref.read(regenciesProvider).whenData((cities) {
      final query = _normalizePlace(birthPlace);
      if (query.isEmpty) return;

      Region? match;

      // 1. Exact match on normalised name
      for (final c in cities) {
        if (_normalizePlace(c.name) == query) { match = c; break; }
      }

      // 2. Exact match after stripping KABUPATEN / KOTA prefix from both sides
      if (match == null) {
        final queryStripped = _stripRegencyPrefix(query);
        if (queryStripped.isNotEmpty) {
          for (final c in cities) {
            if (_stripRegencyPrefix(_normalizePlace(c.name)) == queryStripped) {
              match = c; break;
            }
          }
        }
      }

      // 3. Substring match (normalised)
      if (match == null) {
        for (final c in cities) {
          final cn = _normalizePlace(c.name);
          if (cn.contains(query) || query.contains(cn)) { match = c; break; }
        }
      }

      // 4. Substring match after stripping prefixes
      if (match == null) {
        final queryStripped = _stripRegencyPrefix(query);
        if (queryStripped.length >= 3) {
          for (final c in cities) {
            final cn = _stripRegencyPrefix(_normalizePlace(c.name));
            if (cn.contains(queryStripped) || queryStripped.contains(cn)) {
              match = c; break;
            }
          }
        }
      }

      if (match != null && mounted) {
        setState(() => _selectedCity = match);
      }
    });
  }

  void _parseAndSetDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final d = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        _selectedDate = DateTime(y, m, d);
      }
    } catch (_) {}
  }

  void _clearFields() {
    setState(() {
      _nikController.clear();
      _nameController.clear();
      _selectedCity = null;
      _selectedDate = null;
      _ocrBirthPlace = null;
    });
  }

  /// Extracts a clean, user-friendly message from any thrown error.
  /// Handles [DioException] (which [AuthRepository._handleError] already
  /// enriches with the backend `detail` string) as well as plain exceptions.
  String _extractMessage(Object e) {
    if (e is DioException) {
      // _handleError already copies the backend `detail` into .message.
      final msg = e.message;
      if (msg != null && msg.isNotEmpty) return msg;

      // Fallback: read directly from the raw response body.
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'] as String?;
        if (detail != null && detail.isNotEmpty) return detail;

        // Field-level validation errors, e.g. {"email": ["already taken"]}.
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return errors.entries.map((entry) {
            final v = entry.value;
            if (v is List && v.isNotEmpty) return v.first.toString();
            return v.toString();
          }).join('\n');
        }
      }

      // Network / connectivity errors.
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

    // Generic fallback — strip leading exception class name if present.
    final raw = e.toString();
    final colonIdx = raw.lastIndexOf(': ');
    if (colonIdx != -1 && colonIdx + 2 < raw.length) {
      return raw.substring(colonIdx + 2);
    }
    return raw;
  }

  //  Pickers 

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
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryDarkGreen,
            onPrimary: Colors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showCityPicker() async {
    final cities = ref.read(regenciesProvider).valueOrNull;
    if (cities == null) {
      CustomToast.show(context,
          message: 'Data kota sedang dimuat, coba lagi sebentar',
          type: ToastType.info);
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
      setState(() => _selectedCity = result);
    }
  }

  //  Registration 

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(registrationProvider.notifier).updateKtpData(
          KtpData(
            nik: _nikController.text.trim(),
            name: _nameController.text.trim(),
            birthPlace: _selectedCity?.name ?? '',
            birthDate: _formattedDate,
          ),
        );

    try {
      setState(() => _isRegistering = true);

      // completeRegistration now returns the AuthResponse so we don't need
      // a second network call to /me/ just to get the user.
      final authResponse =
          await ref.read(registrationProvider.notifier).completeRegistration();
      if (!mounted) return;

      ref.read(registrationProvider.notifier).reset();

      // Show toast BEFORE triggering the auth-state update. The overlay
      // belongs to the stable GoRouter's navigator and persists across
      // route transitions, so the toast will remain visible on the home page.
      CustomToast.show(context,
          message: 'Registrasi berhasil! Selamat datang 🎉',
          type: ToastType.success,
          duration: const Duration(seconds: 4));

      // Update auth state with the user returned by the registration response.
      // The stable GoRouter's refreshListenable will detect the change and
      // automatically redirect to /home — no manual context.go needed.
      ref
          .read(authStateProvider.notifier)
          .setAuthenticatedUser(authResponse.user);
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
    final state = ref.watch(registrationProvider);
    // Pre-fetch regencies so they are warm when the city picker opens.
    ref.watch(regenciesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            _buildKtpUploadSection(state.ktpImage),

            if (state.isProcessing && !_isRegistering) ...[
              const SizedBox(height: 16),
              _buildOcrProgressIndicator(),
            ],

            const SizedBox(height: 32),
            _buildDataFields(state),
          ],
        ),
      ),
    );
  }

  //  Header 

  Widget _buildHeader() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepIndicator(isActive: false, isCompleted: true, stepNumber: '1'),
            _StepConnector(),
            _StepIndicator(isActive: true, isCompleted: false, stepNumber: '2'),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Upload KTP & Data Diri',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Langkah 2: Upload KTP dan lengkapi data',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.textMedium,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  //  KTP image upload 

  Widget _buildKtpUploadSection(File? ktpImage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto KTP',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isPickingImage ? null : _showImageSourceSheet,
          child: AspectRatio(
            aspectRatio: 1.586,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ktpImage != null
                      ? AppColors.primaryDarkGreen
                      : AppColors.divider.withValues(alpha: 0.8),
                  width: ktpImage != null ? 2 : 1.5,
                ),
              ),
              child: ktpImage != null
                  ? _buildKtpPreview(ktpImage)
                  : _buildKtpPlaceholder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKtpPreview(File image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Image.file(image,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 800),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _showImageSourceSheet,
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

  Widget _buildKtpPlaceholder() {
    if (_isPickingImage) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryDarkGreen),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryDarkGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_photo_alternate_outlined,
                size: 32, color: AppColors.primaryDarkGreen),
          ),
          const SizedBox(height: 16),
          Text('Ketuk untuk upload foto KTP',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Pastikan foto jelas dan terang',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  //  OCR progress 

  Widget _buildOcrProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryDarkGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryDarkGreen),
          ),
          const SizedBox(width: 12),
          Text(
            'Memproses OCR dari foto KTP...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.primaryDarkGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  //  Data form fields 

  Widget _buildDataFields(RegistrationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Data Diri',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Periksa dan lengkapi data diri Anda sesuai KTP',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textMedium,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 20),

        // NIK
        _buildTextField(
          controller: _nikController,
          label: 'NIK',
          hint: '16 digit angka',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
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
        _buildTextField(
          controller: _nameController,
          label: 'Nama Lengkap',
          hint: 'Sesuai KTP',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Nama wajib diisi' : null,
        ),
        const SizedBox(height: 16),

        // Tempat Lahir  city picker
        _buildPickerField(
          label: 'Tempat Lahir',
          hint: 'Pilih kota/kabupaten',
          icon: Icons.location_on_outlined,
          displayValue: _selectedCity?.name,
          onTap: _showCityPicker,
          validator: (_) =>
              _selectedCity == null ? 'Tempat lahir wajib dipilih' : null,
        ),
        const SizedBox(height: 16),

        // Tanggal Lahir  date picker
        _buildPickerField(
          label: 'Tanggal Lahir',
          hint: 'Pilih tanggal lahir',
          icon: Icons.calendar_today_outlined,
          displayValue: _formattedDate.isEmpty ? null : _formattedDate,
          onTap: _selectDate,
          validator: (_) =>
              _selectedDate == null ? 'Tanggal lahir wajib dipilih' : null,
        ),

        const SizedBox(height: 32),

        // Register button  full width via stretch column + SizedBox
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                (state.isProcessing || _isRegistering) ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDarkGreen,
              foregroundColor: AppColors.white,
              disabledBackgroundColor:
                  AppColors.primaryDarkGreen.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isRegistering
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
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
        ),
      ],
    );
  }

  //  Field builders 

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: AppColors.textDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(label: label, hint: hint, icon: icon),
      validator: validator,
    );
  }

  /// Read-only tap-to-open field for date / city pickers.
  Widget _buildPickerField({
    required String label,
    required String hint,
    required IconData icon,
    required String? displayValue,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return FormField<String>(
      validator: validator,
      builder: (fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: _inputDecoration(
                  label: label,
                  hint: hint,
                  icon: icon,
                  suffixIcon: Icons.arrow_drop_down_rounded,
                  hasError: fieldState.hasError,
                ),
                child: Text(
                  displayValue ?? hint,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: displayValue != null
                        ? AppColors.textDark
                        : AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (fieldState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 14),
                child: Text(
                  fieldState.errorText!,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    IconData? suffixIcon,
    bool hasError = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.textMedium,
        fontWeight: FontWeight.w500,
      ),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.textLight,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: AppColors.textMedium, size: 22),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: AppColors.textMedium, size: 28)
          : null,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: hasError
                ? AppColors.error
                : AppColors.divider.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.primaryDarkGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
    this.selected,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  late final TextEditingController _searchController;
  late List<Region> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch);
    _filtered = _filterCities(widget.initialSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Region> _filterCities(String query) {
    if (query.isEmpty) return widget.cities;
    final q = query.toLowerCase();
    return widget.cities.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Pilih Tempat Lahir',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMedium),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (v) =>
                      setState(() => _filtered = _filterCities(v)),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Cari kota / kabupaten...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: AppColors.textLight),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textMedium, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppColors.textMedium, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filtered = widget.cities);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filtered.length} hasil ditemukan',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.textMedium),
                  ),
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded,
                                size: 48, color: AppColors.textLight),
                            const SizedBox(height: 8),
                            Text('Tidak ada hasil',
                                style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMedium,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final city = _filtered[i];
                          final isSelected = city == widget.selected;
                          return ListTile(
                            onTap: () => Navigator.pop(context, city),
                            selected: isSelected,
                            selectedTileColor: AppColors.primaryDarkGreen
                                .withValues(alpha: 0.07),
                            title: Text(
                              city.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primaryDarkGreen
                                    : AppColors.textDark,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded,
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

//  Step indicator widgets 

class _StepIndicator extends StatelessWidget {
  final bool isActive;
  final bool isCompleted;
  final String stepNumber;

  const _StepIndicator({
    required this.isActive,
    required this.isCompleted,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive || isCompleted
            ? AppColors.primaryDarkGreen
            : AppColors.divider,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                stepNumber,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 2,
      color: AppColors.primaryDarkGreen,
    );
  }
}
