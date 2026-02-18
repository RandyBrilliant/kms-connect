import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../domain/models/applicant_profile.dart';
import '../../domain/models/work_experience.dart';

class ProfileRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get current user's profile
  Future<ApplicantProfile> getProfile() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.myProfile);
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal mengambil profil',
        );
      }

      return ApplicantProfile.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update profile
  Future<ApplicantProfile> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.patch(
        ApiEndpoints.myProfile,
        data: data,
      );
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal memperbarui profil',
        );
      }

      return ApplicantProfile.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Submit profile for verification
  Future<ApplicantProfile> submitForVerification() async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiEndpoints.myProfile}submit_for_verification/',
      );
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal mengirim profil untuk verifikasi',
        );
      }

      return ApplicantProfile.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get work experiences
  Future<List<WorkExperience>> getWorkExperiences() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.myWorkExperiences);
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        return [];
      }

      return (apiResponse.data as List)
          .map((json) => WorkExperience.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create work experience
  Future<WorkExperience> createWorkExperience(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.myWorkExperiences,
        data: data,
      );
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal menambah pengalaman kerja',
        );
      }

      return WorkExperience.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update work experience
  Future<WorkExperience> updateWorkExperience(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.patch(
        '${ApiEndpoints.myWorkExperiences}$id/',
        data: data,
      );
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal memperbarui pengalaman kerja',
        );
      }

      return WorkExperience.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete work experience
  Future<void> deleteWorkExperience(int id) async {
    try {
      await _apiClient.dio.delete('${ApiEndpoints.myWorkExperiences}$id/');
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
