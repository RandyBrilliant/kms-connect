import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/account_deletion_request.dart';
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
  bool _disposed = false;

  WorkExperienceNotifier(this._repository, this._ref)
      : super(const WorkExperienceState()) {
    _load();
  }

  Future<void> _load() async {
    _setStateSafely(state.copyWith(isLoading: true, error: null));
    try {
      final items = await _repository.getWorkExperiences();
      _setStateSafely(state.copyWith(items: items, isLoading: false));
    } catch (e) {
      _setStateSafely(state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      ));
    }
  }

  Future<void> reload() => _load();

  Future<bool> create(Map<String, dynamic> data) async {
    _setStateSafely(state.copyWith(isLoading: true, error: null));
    try {
      final created = await _repository.createWorkExperience(data);
      _setStateSafely(state.copyWith(
        items: [...state.items, created],
        isLoading: false,
      ));
      _ref.invalidate(workExperiencesProvider);
      return true;
    } catch (e) {
      _setStateSafely(state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      ));
      return false;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    _setStateSafely(state.copyWith(isLoading: true, error: null));
    try {
      final updated = await _repository.updateWorkExperience(id, data);
      _setStateSafely(state.copyWith(
        items: state.items.map((e) => e.id == id ? updated : e).toList(),
        isLoading: false,
      ));
      _ref.invalidate(workExperiencesProvider);
      return true;
    } catch (e) {
      _setStateSafely(state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      ));
      return false;
    }
  }

  Future<bool> delete(int id) async {
    _setStateSafely(state.copyWith(isLoading: true, error: null));
    try {
      await _repository.deleteWorkExperience(id);
      _setStateSafely(state.copyWith(
        items: state.items.where((e) => e.id != id).toList(),
        isLoading: false,
      ));
      _ref.invalidate(workExperiencesProvider);
      return true;
    } catch (e) {
      _setStateSafely(state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      ));
      return false;
    }
  }

  void _setStateSafely(WorkExperienceState nextState) {
    if (_disposed) return;
    state = nextState;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ─── Biodata PDF ─────────────────────────────────────────────────────────────

class BiodataPdfState {
  final bool isLoading;
  final String? error;
  const BiodataPdfState({this.isLoading = false, this.error});
  BiodataPdfState copyWith({bool? isLoading, String? error}) {
    return BiodataPdfState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BiodataPdfNotifier extends StateNotifier<BiodataPdfState> {
  final ProfileRepository _repository;
  BiodataPdfNotifier(this._repository) : super(const BiodataPdfState());

  Future<bool> open() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.downloadAndOpenBiodataPdf();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final biodataPdfProvider =
    StateNotifierProvider<BiodataPdfNotifier, BiodataPdfState>((ref) {
  return BiodataPdfNotifier(ref.read(profileRepositoryProvider));
});

// ─── Psychology referral PDF (lamaran DITERIMA only) ────────────────────────

class PsychologyReferralPdfState {
  final bool isLoading;
  final String? error;
  const PsychologyReferralPdfState({this.isLoading = false, this.error});
  PsychologyReferralPdfState copyWith({bool? isLoading, String? error}) {
    return PsychologyReferralPdfState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PsychologyReferralPdfNotifier
    extends StateNotifier<PsychologyReferralPdfState> {
  final ProfileRepository _repository;
  PsychologyReferralPdfNotifier(this._repository)
      : super(const PsychologyReferralPdfState());

  Future<bool> open() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.downloadAndOpenPsychologyReferralPdf();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final psychologyReferralPdfProvider =
    StateNotifierProvider<PsychologyReferralPdfNotifier, PsychologyReferralPdfState>(
        (ref) {
  return PsychologyReferralPdfNotifier(ref.read(profileRepositoryProvider));
});

// ─── Medical referral PDF (lamaran DITERIMA only) ───────────────────────────

class MedicalReferralPdfState {
  final bool isLoading;
  final String? error;
  const MedicalReferralPdfState({this.isLoading = false, this.error});
  MedicalReferralPdfState copyWith({bool? isLoading, String? error}) {
    return MedicalReferralPdfState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MedicalReferralPdfNotifier extends StateNotifier<MedicalReferralPdfState> {
  final ProfileRepository _repository;
  MedicalReferralPdfNotifier(this._repository)
      : super(const MedicalReferralPdfState());

  Future<bool> open() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.downloadAndOpenMedicalReferralPdf();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final medicalReferralPdfProvider =
    StateNotifierProvider<MedicalReferralPdfNotifier, MedicalReferralPdfState>((ref) {
  return MedicalReferralPdfNotifier(ref.read(profileRepositoryProvider));
});

final profileNotifierProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.read(profileRepositoryProvider));
});

class ProfileState {
  final ApplicantProfile? profile;
  final bool isLoading;
  final String? error;

  /// When the profile was last successfully fetched from the server.
  final DateTime? lastFetchedAt;

  ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.lastFetchedAt,
  });

  ProfileState copyWith({
    ApplicantProfile? profile,
    bool? isLoading,
    String? error,
    DateTime? lastFetchedAt,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  /// How long cached profile data stays fresh before a network
  /// re-fetch is attempted.
  static const _cacheTtl = Duration(minutes: 5);

  ProfileNotifier(this._repository) : super(ProfileState());

  /// Load profile data, skipping the network call if the cache is fresh.
  ///
  /// Pass [force] = true to bypass the TTL and always hit the server
  /// (e.g. after the user edits their profile).
  Future<void> loadProfile({bool force = false}) async {
    if (state.isLoading) return;

    // Return cached data if it's still within the TTL window.
    if (!force &&
        state.profile != null &&
        state.lastFetchedAt != null &&
        DateTime.now().difference(state.lastFetchedAt!) < _cacheTtl) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.getProfile();
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        lastFetchedAt: DateTime.now(),
      );
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
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        lastFetchedAt: DateTime.now(),
      );
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
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        lastFetchedAt: DateTime.now(),
      );
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

// ─── Account Deletion Request ─────────────────────────────────────────────────

class AccountDeletionRequestState {
  final AccountDeletionRequest? request;
  final bool isLoading;
  final String? error;

  const AccountDeletionRequestState({
    this.request,
    this.isLoading = false,
    this.error,
  });

  AccountDeletionRequestState copyWith({
    AccountDeletionRequest? request,
    bool? isLoading,
    String? error,
    bool clearRequest = false,
  }) {
    return AccountDeletionRequestState(
      request: clearRequest ? null : (request ?? this.request),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get hasRequest => request != null;
  bool get hasPendingRequest => request?.isPending ?? false;
}

class AccountDeletionRequestNotifier extends StateNotifier<AccountDeletionRequestState> {
  final ProfileRepository _repository;

  AccountDeletionRequestNotifier(this._repository)
      : super(const AccountDeletionRequestState());

  /// Load the current deletion request (if any)
  Future<void> loadRequest() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final request = await _repository.getMyDeletionRequest();
      state = state.copyWith(
        request: request,
        isLoading: false,
        clearRequest: request == null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
    }
  }

  /// Submit a new deletion request
  Future<bool> submitRequest({String? reason}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final request = await _repository.submitDeletionRequest(reason: reason);
      state = state.copyWith(request: request, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('DioException: ', ''),
      );
      return false;
    }
  }

  /// Cancel the pending deletion request
  Future<bool> cancelRequest() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.cancelDeletionRequest();
      state = state.copyWith(
        isLoading: false,
        clearRequest: true,
      );
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

final accountDeletionRequestProvider =
    StateNotifierProvider<AccountDeletionRequestNotifier, AccountDeletionRequestState>((ref) {
  return AccountDeletionRequestNotifier(ref.read(profileRepositoryProvider));
});
