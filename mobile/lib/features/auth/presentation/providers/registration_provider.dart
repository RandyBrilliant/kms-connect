import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/auth_response.dart';
import '../../domain/models/ktp_data.dart';
import '../../data/repositories/auth_repository.dart';

/// Registration flow state
class RegistrationState {
  final int currentStep;
  final String? email;
  final String? password;
  final String? referralCode;
  final String? phoneNumber;
  final File? ktpImage;
  final KtpData? ktpData;
  final bool isProcessing;
  final String? error;

  /// Confirmed birth place region ID (FK → regions.Regency).
  final int? birthPlaceId;

  /// Confirmed birth date in ISO format (yyyy-MM-dd).
  final String? birthDateIso;

  /// Pernyataan data benar (form pernyataan CPMI).
  final bool dataDeclarationConfirmed;

  /// Paham zero cost (form RBA zero cost).
  final bool zeroCostUnderstood;

  RegistrationState({
    this.currentStep = 0,
    this.email,
    this.password,
    this.referralCode,
    this.phoneNumber,
    this.ktpImage,
    this.ktpData,
    this.isProcessing = false,
    this.error,
    this.birthPlaceId,
    this.birthDateIso,
    this.dataDeclarationConfirmed = false,
    this.zeroCostUnderstood = false,
  });

  RegistrationState copyWith({
    int? currentStep,
    String? email,
    String? password,
    String? referralCode,
    String? phoneNumber,
    File? ktpImage,
    KtpData? ktpData,
    bool? isProcessing,
    String? error,
    int? birthPlaceId,
    String? birthDateIso,
    bool? dataDeclarationConfirmed,
    bool? zeroCostUnderstood,
  }) {
    return RegistrationState(
      currentStep: currentStep ?? this.currentStep,
      email: email ?? this.email,
      password: password ?? this.password,
      referralCode: referralCode ?? this.referralCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      ktpImage: ktpImage ?? this.ktpImage,
      ktpData: ktpData ?? this.ktpData,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      birthPlaceId: birthPlaceId ?? this.birthPlaceId,
      birthDateIso: birthDateIso ?? this.birthDateIso,
      dataDeclarationConfirmed:
          dataDeclarationConfirmed ?? this.dataDeclarationConfirmed,
      zeroCostUnderstood:
          zeroCostUnderstood ?? this.zeroCostUnderstood,
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
    String? phoneNumber,
  }) {
    state = state.copyWith(
      email: email,
      password: password,
      referralCode: referralCode,
      phoneNumber: phoneNumber,
    );
  }

  void setKtpImage(File image) {
    state = state.copyWith(ktpImage: image);
  }

  /// Saves the confirmed birth place region ID and ISO birth date from step 2.
  void setBirthInfo({int? birthPlaceId, String? birthDateIso}) {
    state = state.copyWith(
      birthPlaceId: birthPlaceId,
      birthDateIso: birthDateIso,
    );
  }

  void setDeclarations({
    required bool dataDeclarationConfirmed,
    required bool zeroCostUnderstood,
  }) {
    state = state.copyWith(
      dataDeclarationConfirmed: dataDeclarationConfirmed,
      zeroCostUnderstood: zeroCostUnderstood,
    );
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

  /// Complete registration with all data. Returns the [AuthResponse] so the
  /// caller can immediately set the authenticated user without an extra
  /// network round-trip.
  Future<AuthResponse> completeRegistration() async {
    if (state.email == null ||
        state.password == null ||
        state.ktpData?.nik == null ||
        state.ktpImage == null) {
      state = state.copyWith(error: 'Data registrasi tidak lengkap');
      throw Exception('Data registrasi tidak lengkap');
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final authResponse = await _authRepository.registerComplete(
        email: state.email!,
        password: state.password!,
        nik: state.ktpData!.nik!,
        ktpFile: state.ktpImage!,
        referralCode: state.referralCode,
        fullName: state.ktpData?.name,
        phoneNumber: state.phoneNumber,
        birthPlaceId: state.birthPlaceId,
        birthDateIso: state.birthDateIso,
        dataDeclarationConfirmed: state.dataDeclarationConfirmed,
        zeroCostUnderstood: state.zeroCostUnderstood,
      );
      state = state.copyWith(isProcessing: false);
      return authResponse;
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
