import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../domain/models/job.dart';
import '../../domain/models/job_application.dart';

class JobRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get public jobs list
  Future<List<Job>> getJobs({
    String? search,
    String? employmentType,
    String? locationCountry,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
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

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        return [];
      }

      return (apiResponse.data as List)
          .map((json) => Job.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get job detail
  Future<Job> getJobDetail(int id) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.jobDetail(id));
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal mengambil detail lowongan',
        );
      }

      return Job.fromJson(apiResponse.data!);
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

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        return [];
      }

      return (apiResponse.data as List)
          .map((json) => JobApplication.fromJson(json as Map<String, dynamic>))
          .toList();
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
