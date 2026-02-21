import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../config/colors.dart';
import '../../../../../core/widgets/custom_toast.dart';
import '../../../../../core/widgets/ktp_camera_screen.dart';
import '../../../domain/models/ktp_data.dart';
import '../../providers/registration_provider.dart';

class RegistrationStep2Ktp extends ConsumerStatefulWidget {
  const RegistrationStep2Ktp({super.key});

  @override
  ConsumerState<RegistrationStep2Ktp> createState() =>
      _RegistrationStep2KtpState();
}

class _RegistrationStep2KtpState extends ConsumerState<RegistrationStep2Ktp> {
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedGender;
  bool _isProcessingOcr = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if returning to this step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ktpData = ref.read(registrationProvider).ktpData;
      if (ktpData != null) {
        _populateFieldsFromOcr(ktpData);
      }
    });
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _birthPlaceController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceActionSheet() async {
    if (_isPickingImage) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt,
                      color: AppColors.primaryDarkGreen),
                  title: Text(
                    'Kamera',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library,
                      color: AppColors.primaryDarkGreen),
                  title: Text(
                    'Galeri',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source != null) {
      await _processImagePicker(source);
    }
  }

  Future<void> _processImagePicker(ImageSource source) async {
    if (_isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      File? imageFile;

      if (source == ImageSource.camera) {
        // Request camera permission
        final status = await Permission.camera.request();

        if (!mounted) return;

        if (status.isDenied || status.isPermanentlyDenied) {
          CustomToast.show(
            context,
            message: 'Izin kamera diperlukan untuk mengambil foto',
            type: ToastType.error,
          );
          if (status.isPermanentlyDenied) {
            await openAppSettings();
          }
          return;
        }

        // Use custom camera screen with KTP guidelines
        final File? capturedFile = await Navigator.push<File>(
          context,
          MaterialPageRoute(
            builder: (_) => const KtpCameraScreen(),
          ),
        );

        if (capturedFile == null || !mounted) return;
        imageFile = capturedFile;
      } else {
        // Gallery: use ImagePicker directly (handles its own permissions)
        final ImagePicker picker = ImagePicker();
        final XFile? pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1080,
        );

        if (pickedFile == null || !mounted) return;
        imageFile = File(pickedFile.path);
      }

      // Set image directly — avoids image_cropper "Reply already submitted" crash
      ref.read(registrationProvider.notifier).setKtpImage(imageFile);
    } on PlatformException catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Izin ditolak: ${e.message}',
        type: ToastType.error,
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal memproses gambar',
        type: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _processOcr() async {
    if (_isProcessingOcr) return;
    setState(() => _isProcessingOcr = true);

    try {
      await ref.read(registrationProvider.notifier).processOcr();

      if (!mounted) return;

      final ktpData = ref.read(registrationProvider).ktpData;
      if (ktpData != null) {
        _populateFieldsFromOcr(ktpData);
        CustomToast.show(
          context,
          message: 'Data KTP berhasil diekstrak! Silakan periksa dan lengkapi.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal memproses OCR: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  void _populateFieldsFromOcr(KtpData data) {
    if (data.nik != null) _nikController.text = data.nik!;
    if (data.name != null) _nameController.text = data.name!;
    if (data.birthPlace != null) _birthPlaceController.text = data.birthPlace!;
    if (data.birthDate != null) _birthDateController.text = data.birthDate!;
    if (data.address != null) _addressController.text = data.address!;
    if (data.gender != null) {
      setState(() => _selectedGender = data.gender);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(registrationProvider.notifier).updateKtpData(
          KtpData(
            nik: _nikController.text,
            name: _nameController.text,
            birthPlace: _birthPlaceController.text,
            birthDate: _birthDateController.text,
            address: _addressController.text,
            gender: _selectedGender,
          ),
        );

    try {
      await ref.read(registrationProvider.notifier).completeRegistration();

      if (!mounted) return;

      CustomToast.show(
        context,
        message: 'Registrasi berhasil!',
        type: ToastType.success,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal registrasi: $e',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            _buildKtpUploadSection(state.ktpImage),
            if (state.ktpImage != null) ...[
              const SizedBox(height: 24),
              _buildOcrProcessButton(),
              const SizedBox(height: 24),
              _buildDataFields(),
            ],
          ],
        ),
      ),
    );
  }

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

  Widget _buildKtpUploadSection(File? ktpImage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto KTP',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isPickingImage ? null : _showImageSourceActionSheet,
          child: AspectRatio(
            aspectRatio: 1.586,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ktpImage != null
                      ? AppColors.primaryDarkGreen
                      : AppColors.divider.withOpacity(0.5),
                  width: ktpImage != null ? 2 : 1.5,
                ),
              ),
              child: ktpImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.file(
                            ktpImage,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _showImageSourceActionSheet,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: _isPickingImage
                          ? const CircularProgressIndicator(
                              color: AppColors.primaryDarkGreen,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 48,
                                  color: AppColors.textMedium,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Ketuk untuk upload foto KTP',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppColors.textMedium,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rasio KTP (landscape)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOcrProcessButton() {
    final state = ref.watch(registrationProvider);
    final hasOcrData = state.ktpData != null;

    return ElevatedButton.icon(
      onPressed: _isProcessingOcr ? null : _processOcr,
      icon: _isProcessingOcr
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(hasOcrData ? Icons.refresh : Icons.scanner),
      label: Text(
        _isProcessingOcr
            ? 'Memproses OCR...'
            : hasOcrData
                ? 'Proses Ulang OCR'
                : 'Ekstrak Data dari KTP',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: hasOcrData
            ? AppColors.secondaryLightGreen
            : AppColors.primaryDarkGreen,
        foregroundColor:
            hasOcrData ? AppColors.primaryDarkGreen : AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }

  Widget _buildDataFields() {
    final state = ref.watch(registrationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Diri',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 16),
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
          validator: (value) {
            if (value == null || value.isEmpty) return 'NIK wajib diisi';
            if (value.length != 16) return 'NIK harus 16 digit';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _nameController,
          label: 'Nama Lengkap',
          hint: 'Sesuai KTP',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Nama wajib diisi';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _birthPlaceController,
          label: 'Tempat Lahir',
          hint: 'Contoh: Jakarta',
          icon: Icons.location_on_outlined,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Tempat lahir wajib diisi';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _birthDateController,
          label: 'Tanggal Lahir',
          hint: 'DD-MM-YYYY',
          icon: Icons.calendar_today_outlined,
          keyboardType: TextInputType.datetime,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Tanggal lahir wajib diisi';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Alamat',
          hint: 'Sesuai KTP',
          icon: Icons.home_outlined,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Alamat wajib diisi';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildGenderDropdown(),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: state.isProcessing ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDarkGreen,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: state.isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
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
      ],
    );
  }

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
      decoration: InputDecoration(
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
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.divider.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: AppColors.primaryDarkGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedGender),
      initialValue: _selectedGender,
      decoration: InputDecoration(
        labelText: 'Jenis Kelamin',
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMedium,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(Icons.wc_outlined,
            color: AppColors.textMedium, size: 22),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.divider.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: AppColors.primaryDarkGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      items: [
        DropdownMenuItem(
          value: 'M',
          child: Text(
            'Laki-laki',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DropdownMenuItem(
          value: 'F',
          child: Text(
            'Perempuan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _selectedGender = value),
      validator: (value) {
        if (value == null) return 'Jenis kelamin wajib dipilih';
        return null;
      },
    );
  }
}

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
