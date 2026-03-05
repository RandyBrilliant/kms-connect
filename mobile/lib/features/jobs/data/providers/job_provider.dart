import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/paginated_state.dart';
import '../../../../core/utils/retry.dart';
import '../../domain/models/batch_announcement.dart';
import '../../domain/models/job.dart';
import '../../domain/models/job_application.dart';
import '../repositories/job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository();
});

// ─────────────────────────────────────────────────────────────────────────────
// Filter value object
// ─────────────────────────────────────────────────────────────────────────────

class JobFilters {
  final String? search;
  final String? employmentType;
  final String? locationCountry;

  JobFilters({
    this.search,
    this.employmentType,
    this.locationCountry,
  });

  Map<String, String?> toMap() {
    return {
      'search': search,
      'employment_type': employmentType,
      'location_country': locationCountry,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobFilters &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          employmentType == other.employmentType &&
          locationCountry == other.locationCountry;

  @override
  int get hashCode =>
      search.hashCode ^
      employmentType.hashCode ^
      locationCountry.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// Paginated jobs notifier
// ─────────────────────────────────────────────────────────────────────────────

class PaginatedJobsNotifier extends StateNotifier<PaginatedState<Job>> {
  PaginatedJobsNotifier(this._repository, this._filters)
      : super(const PaginatedState<Job>()) {
    loadFirstPage();
  }

  final JobRepository _repository;
  final JobFilters _filters;

  /// Load (or reload) the first page.
  Future<void> loadFirstPage() async {
    state = const PaginatedState<Job>(isLoading: true);
    try {
      final response = await retryWithBackoff(
        () => _repository.getJobs(
          search: _filters.search,
          employmentType: _filters.employmentType,
          locationCountry: _filters.locationCountry,
          page: 1,
        ),
      );
      state = PaginatedState<Job>(
        items: response.results,
        currentPage: 1,
        totalCount: response.count,
        hasMore: response.hasNext,
      );
    } catch (e) {
      state = PaginatedState<Job>(error: e.toString());
    }
  }

  /// Load the next page and append results.
  Future<void> loadNextPage() async {
    if (state.isLoadingMore || !state.hasMore) return;

    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await retryWithBackoff(
        () => _repository.getJobs(
          search: _filters.search,
          employmentType: _filters.employmentType,
          locationCountry: _filters.locationCountry,
          page: nextPage,
        ),
      );
      state = state.copyWith(
        items: [...state.items, ...response.results],
        currentPage: nextPage,
        totalCount: response.count,
        hasMore: response.hasNext,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: () => e.toString(),
      );
    }
  }
}

/// Paginated jobs provider — auto-disposes when filters change.
final paginatedJobsProvider = StateNotifierProvider.autoDispose
    .family<PaginatedJobsNotifier, PaginatedState<Job>, JobFilters>(
  (ref, filters) {
    final repository = ref.read(jobRepositoryProvider);
    return PaginatedJobsNotifier(repository, filters);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Non-paginated providers (detail, applications)
// ─────────────────────────────────────────────────────────────────────────────

final jobDetailProvider = FutureProvider.autoDispose.family<Job, int>((ref, jobId) async {
  final repository = ref.read(jobRepositoryProvider);
  return await retryWithBackoff(() => repository.getJobDetail(jobId));
});

final myApplicationsProvider = FutureProvider.autoDispose.family<List<JobApplication>, String?>((ref, status) async {
  final repository = ref.read(jobRepositoryProvider);
  return await retryWithBackoff(() => repository.getMyApplications(status: status));
});

final applicationDetailProvider = FutureProvider.autoDispose.family<JobApplication, int>((ref, applicationId) async {
  final repository = ref.read(jobRepositoryProvider);
  return await retryWithBackoff(() => repository.getApplicationDetail(applicationId));
});

/// Batch announcements for a specific application.
/// Returns an empty list when the application has no batch.
/// Used on PRA_SELEKSI / INTERVIEW stages instead of individual chat.
final applicationAnnouncementsProvider = FutureProvider.autoDispose
    .family<List<BatchAnnouncement>, int>((ref, applicationId) async {
  final repository = ref.read(jobRepositoryProvider);
  return await retryWithBackoff(
    () => repository.getApplicationAnnouncements(applicationId),
  );
});
