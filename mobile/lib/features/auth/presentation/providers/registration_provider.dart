import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ktp_data.dart';
import '../../data/repositories/auth_repository.dart';

/// Registration flow state
class RegistrationState {
  final int currentStep;
  final String? email;
  final String? password;
  final String? referralCode;
  final File? ktpImage;
  final KtpData? ktpData;
  final bool isProcessing;
  final String? error;

  RegistrationState({
    this.currentStep = 0,
    this.email,
    this.password,
    this.referralCode,
    this.ktpImage,
    this.ktpData,
    this.isProcessing = false,
    this.error,
  });

  RegistrationState copyWith({
    int? currentStep,
    String? email,
    String? password,
    String? referralCode,
    File? ktpImage,
    KtpData? ktpData,
    bool? isProcessing,
    String? error,
  }) {
    return RegistrationState(
      currentStep: currentStep ?? this.currentStep,
      email: email ?? this.email,
      password: password ?? this.password,
      referralCode: referralCode ?? this.referralCode,
      ktpImage: ktpImage ?? this.ktpImage,
      ktpData: ktpData ?? this.ktpData,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
    );
  }
}

/// Registration flow notifier
class RegistrationNotifier extends StateNotifier<RegistrationState> {
  final AuthRepository _authRepository;

  RegistrationNotifier(this._authRepository) : super(RegistrationState());

  void nextStep() {
    if (state.currentStep < 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void setCredentials({
    required String email,
    required String password,
    String? referralCode,
  }) {
    state = state.copyWith(
      email: email,
      password: password,
      referralCode: referralCode,
    );
  }

  void setKtpImage(File image) {
    state = state.copyWith(ktpImage: image);
  }

  void updateKtpData(KtpData data) {
    state = state.copyWith(ktpData: data);
  }

  /// Process OCR for KTP image
  Future<void> processOcr() async {
    if (state.ktpImage == null) {
      state = state.copyWith(error: 'Belum ada gambar KTP');
      return;
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final ktpData = await _authRepository.ocrPreview(state.ktpImage!);
      state = state.copyWith(
        ktpData: ktpData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Complete registration with all data
  Future<void> completeRegistration() async {
    if (state.email == null ||
        state.password == null ||
        state.ktpData?.nik == null ||
        state.ktpImage == null) {
      state = state.copyWith(error: 'Data registrasi tidak lengkap');
      return;
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      await _authRepository.registerComplete(
        email: state.email!,
        password: state.password!,
        nik: state.ktpData!.nik!,
        ktpFile: state.ktpImage!,
        referralCode: state.referralCode,
      );
      state = state.copyWith(isProcessing: false);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  void setProcessing(bool isProcessing) {
    state = state.copyWith(isProcessing: isProcessing);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void reset() {
    state = RegistrationState();
  }
}

/// Registration flow provider
final registrationProvider =
    StateNotifierProvider<RegistrationNotifier, RegistrationState>((ref) {
  return RegistrationNotifier(AuthRepository());
});
