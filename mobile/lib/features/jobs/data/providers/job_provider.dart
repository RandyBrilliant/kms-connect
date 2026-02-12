import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/job.dart';
import '../../domain/models/job_application.dart';
import '../repositories/job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository();
});

// Helper class for filter equality
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

final jobsProvider = FutureProvider.family<List<Job>, JobFilters>((ref, filters) async {
  final repository = ref.read(jobRepositoryProvider);
  return await repository.getJobs(
    search: filters.search,
    employmentType: filters.employmentType,
    locationCountry: filters.locationCountry,
  );
});

final jobDetailProvider = FutureProvider.family<Job, int>((ref, jobId) async {
  final repository = ref.read(jobRepositoryProvider);
  return await repository.getJobDetail(jobId);
});

final myApplicationsProvider = FutureProvider.family<List<JobApplication>, String?>((ref, status) async {
  final repository = ref.read(jobRepositoryProvider);
  return await repository.getMyApplications(status: status);
});
