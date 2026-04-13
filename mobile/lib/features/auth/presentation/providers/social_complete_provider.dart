import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/models/ktp_data.dart';
import '../../domain/models/user.dart';

class SocialCompleteState {
  final File? ktpImage;
  final KtpData? ktpData;
  final bool isProcessing;
  final String? error;

  const SocialCompleteState({
    this.ktpImage,
    this.ktpData,
    this.isProcessing = false,
    this.error,
  });

  SocialCompleteState copyWith({
    File? ktpImage,
    KtpData? ktpData,
    bool? isProcessing,
    String? error,
  }) {
    return SocialCompleteState(
      ktpImage: ktpImage ?? this.ktpImage,
      ktpData: ktpData ?? this.ktpData,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
    );
  }
}

class SocialCompleteNotifier extends StateNotifier<SocialCompleteState> {
  final AuthRepository _repository;

  SocialCompleteNotifier(this._repository) : super(const SocialCompleteState());

  void setKtpImage(File image) {
    state = state.copyWith(ktpImage: image);
  }

  void updateKtpData(KtpData data) {
    state = state.copyWith(ktpData: data);
  }

  Future<void> processOcr() async {
    if (state.ktpImage == null) {
      state = state.copyWith(error: 'Belum ada gambar KTP');
      return;
    }
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final ktpData = await _repository.ocrPreview(state.ktpImage!);
      state = state.copyWith(ktpData: ktpData, isProcessing: false);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      rethrow;
    }
  }

  Future<User> completeProfile({
    required String nik,
    required String fullName,
    int? birthPlaceId,
    String? birthDateIso,
  }) async {
    if (state.ktpImage == null) {
      throw Exception('File KTP belum diunggah');
    }
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final user = await _repository.socialComplete(
        nik: nik,
        ktpFile: state.ktpImage!,
        fullName: fullName,
        birthPlaceId: birthPlaceId,
        birthDateIso: birthDateIso,
      );
      state = state.copyWith(isProcessing: false);
      return user;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      rethrow;
    }
  }

  void reset() {
    state = const SocialCompleteState();
  }
}

final socialCompleteProvider =
    StateNotifierProvider<SocialCompleteNotifier, SocialCompleteState>((ref) {
  return SocialCompleteNotifier(AuthRepository());
});
