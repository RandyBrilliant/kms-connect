import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/models/paginated_state.dart';
import '../../domain/models/job.dart';
import '../../domain/models/job_application.dart';

class JobRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get public jobs list (paginated).
  ///
  /// Backend returns DRF `PageNumberPagination` format:
  /// `{ "count": N, "next": "…?page=X", "previous": …, "results": [...] }`
  Future<PaginatedResponse<Job>> getJobs({
    String? search,
    String? employmentType,
    String? locationCountry,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (employmentType != null && employmentType.isNotEmpty) {
        queryParams['employment_type'] = employmentType;
      }
      if (locationCountry != null && locationCountry.isNotEmpty) {
        queryParams['location_country'] = locationCountry;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.publicJobs,
        queryParameters: queryParams,
      );

      final data = response.data;

      // Handle paginated envelope { count, next, results }
      if (data is Map<String, dynamic> && data['results'] is List) {
        final results = (data['results'] as List)
            .map((json) => Job.fromJson(json as Map<String, dynamic>))
            .toList();
        return PaginatedResponse<Job>(
          count: (data['count'] as num?)?.toInt() ?? results.length,
          results: results,
          hasNext: data['next'] != null,
        );
      }

      // Fallback: raw array (shouldn't happen after backend change)
      if (data is List) {
        final results = data
            .map((json) => Job.fromJson(json as Map<String, dynamic>))
            .toList();
        return PaginatedResponse<Job>(
          count: results.length,
          results: results,
          hasNext: false,
        );
      }

      return const PaginatedResponse<Job>(
          count: 0, results: [], hasNext: false);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get job detail
  Future<Job> getJobDetail(int id) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.jobDetail(id));
      // Detail endpoints return a plain JSON object (no envelope).
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Gagal mengambil detail lowongan',
        );
      }
      return Job.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Apply for a job
  Future<JobApplication> applyForJob(int jobId) async {
    try {
      final response = await _apiClient.dio.post(ApiEndpoints.applyForJob(jobId));
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal melamar pekerjaan',
        );
      }

      return JobApplication.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get my applications
  Future<List<JobApplication>> getMyApplications({String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.myApplications,
        queryParameters: queryParams,
      );

      // Returns a raw JSON array or paginated envelope
      final data = response.data;
      if (data is List) {
        return data
            .map((json) => JobApplication.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      // Handle paginated response
      if (data is Map<String, dynamic> && data['results'] is List) {
        return (data['results'] as List)
            .map((json) => JobApplication.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get single application detail (includes status_history)
  Future<JobApplication> getApplicationDetail(int id) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.applicationDetail(id),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return JobApplication.fromJson(data);
      }
      // Unwrap ApiResponse envelope if present
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      if (apiResponse.data != null) {
        return JobApplication.fromJson(apiResponse.data!);
      }
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Gagal mengambil detail lamaran',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  DioException _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'] as String?;
        if (detail != null) {
          return DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            message: detail,
          );
        }
      }
    }
    return error;
  }
}
