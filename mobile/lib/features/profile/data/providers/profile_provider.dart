import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/applicant_profile.dart';
import '../../domain/models/work_experience.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileProvider = FutureProvider<ApplicantProfile>((ref) async {
  final repository = ref.read(profileRepositoryProvider);
  return await repository.getProfile();
});

final workExperiencesProvider = FutureProvider<List<WorkExperience>>((ref) async {
  final repository = ref.read(profileRepositoryProvider);
  return await repository.getWorkExperiences();
});

final profileNotifierProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.read(profileRepositoryProvider));
});

class ProfileState {
  final ApplicantProfile? profile;
  final bool isLoading;
  final String? error;

  ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    ApplicantProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(ProfileState()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.getProfile();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.updateProfile(data);
      state = state.copyWith(profile: profile, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
      return false;
    }
  }

  Future<bool> submitForVerification() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.submitForVerification();
      state = state.copyWith(profile: profile, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
      return false;
    }
  }
}
