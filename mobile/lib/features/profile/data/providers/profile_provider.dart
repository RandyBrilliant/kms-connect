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

final workExperienceNotifierProvider =
    StateNotifierProvider<WorkExperienceNotifier, WorkExperienceState>((ref) {
  return WorkExperienceNotifier(ref.read(profileRepositoryProvider), ref);
});

class WorkExperienceState {
  final List<WorkExperience> items;
  final bool isLoading;
  final String? error;

  const WorkExperienceState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  WorkExperienceState copyWith({
    List<WorkExperience>? items,
    bool? isLoading,
    String? error,
  }) {
    return WorkExperienceState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class WorkExperienceNotifier extends StateNotifier<WorkExperienceState> {
  final ProfileRepository _repository;
  final Ref _ref;

  WorkExperienceNotifier(this._repository, this._ref)
      : super(const WorkExperienceState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repository.getWorkExperiences();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
    }
  }

  Future<void> reload() => _load();

  Future<bool> create(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final created = await _repository.createWorkExperience(data);
      state = state.copyWith(
        items: [...state.items, created],
        isLoading: false,
      );
      _ref.invalidate(workExperiencesProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await _repository.updateWorkExperience(id, data);
      state = state.copyWith(
        items: state.items.map((e) => e.id == id ? updated : e).toList(),
        isLoading: false,
      );
      _ref.invalidate(workExperiencesProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
      return false;
    }
  }

  Future<bool> delete(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.deleteWorkExperience(id);
      state = state.copyWith(
        items: state.items.where((e) => e.id != id).toList(),
        isLoading: false,
      );
      _ref.invalidate(workExperiencesProvider);
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

  ProfileNotifier(this._repository) : super(ProfileState());

  /// Call explicitly from pages that need profile data.
  /// NOT called in constructor to avoid duplicate network requests
  /// (HomePage, ProfilePage, EditProfilePage each call this).
  Future<void> loadProfile() async {
    // Skip if already loading to avoid duplicate in-flight requests.
    if (state.isLoading) return;
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
    final profileId = state.profile?.id;
    if (profileId == null) {
      state = state.copyWith(isLoading: false, error: 'Profil belum dimuat');
      return false;
    }
    try {
      final profile = await _repository.updateProfile(profileId, data);
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
