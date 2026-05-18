import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../domain/models/account_deletion_request.dart';
import '../../domain/models/applicant_profile.dart';
import '../../domain/models/work_experience.dart';

class ProfileRepository {
  final ApiClient _apiClient = ApiClient();

  /// Backend uses dedicated codes (`deletion_request_submitted`, etc.) instead of `success`.
  static bool _isDeletionFlowSuccess(ApiResponse<dynamic> r) {
    return r.isSuccess ||
        r.code == 'deletion_request_submitted' ||
        r.code == 'deletion_request_cancelled';
  }

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

  /// Update profile — PATCH to detail URL (router requires /{pk}/ for partial_update)
  Future<ApplicantProfile> updateProfile(int profileId, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.patch(
        '${ApiEndpoints.myProfile}$profileId/',
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

  /// Downloads the applicant's biodata PDF from the server, saves it to the
  /// device's temp directory, and opens it with the system PDF viewer.
  Future<void> downloadAndOpenBiodataPdf() async {
    final response = await _apiClient.dio.get<List<int>>(
      ApiEndpoints.myBiodataPdf,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Server mengembalikan file kosong.');
    }

    final tmpDir = await getTemporaryDirectory();
    final file = File('${tmpDir.path}/biodata_cpmi.pdf');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      throw Exception('Tidak dapat membuka PDF: ${result.message}');
    }
  }

  /// Surat Pengantar Tes Psikologi — same flow as biodata PDF (requires DITERIMA lamaran).
  Future<void> downloadAndOpenPsychologyReferralPdf() async {
    final response = await _apiClient.dio.get<List<int>>(
      ApiEndpoints.myPsychologyReferralPdf,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Server mengembalikan file kosong.');
    }

    final tmpDir = await getTemporaryDirectory();
    final file = File('${tmpDir.path}/pengantar_psikologi_cpmi.pdf');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      throw Exception('Tidak dapat membuka PDF: ${result.message}');
    }
  }

  Future<void> downloadAndOpenMedicalReferralPdf() async {
    final response = await _apiClient.dio.get<List<int>>(
      ApiEndpoints.myMedicalReferralPdf,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Server mengembalikan file kosong.');
    }

    final tmpDir = await getTemporaryDirectory();
    final file = File('${tmpDir.path}/pengantar_medical_cpmi.pdf');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      throw Exception('Tidak dapat membuka PDF: ${result.message}');
    }
  }

  /// Get the current user's deletion request (if any)
  Future<AccountDeletionRequest?> getMyDeletionRequest() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.myDeletionRequest);
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        return null; // No request exists
      }

      return AccountDeletionRequest.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      // 404 means no request exists - not an error
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _handleError(e);
    }
  }

  /// Submit a new account deletion request
  Future<AccountDeletionRequest> submitDeletionRequest({String? reason}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.submitDeletionRequest,
        data: {
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!_isDeletionFlowSuccess(apiResponse) || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal mengajukan permintaan penghapusan akun',
        );
      }

      return AccountDeletionRequest.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Cancel a pending deletion request
  Future<void> cancelDeletionRequest() async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.cancelDeletionRequest,
      );
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!_isDeletionFlowSuccess(apiResponse) || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Gagal membatalkan permintaan',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Picks the first field-level validation message from DRF-style [errors]
  /// (nested maps / lists / strings).
  static String? _firstValidationMessage(dynamic errors) {
    if (errors == null) return null;
    if (errors is List) {
      if (errors.isEmpty) return null;
      final first = errors.first;
      if (first is Map) return _firstValidationMessage(first);
      return first.toString();
    }
    if (errors is Map) {
      for (final e in errors.entries) {
        final key = e.key.toString();
        final v = e.value;
        if (v is List && v.isNotEmpty) {
          return v.first.toString();
        }
        if (v is Map) {
          final nested = _firstValidationMessage(v);
          if (nested != null) return '$key: $nested';
        }
        if (v is String && v.trim().isNotEmpty) {
          return '$key: $v';
        }
      }
    }
    return null;
  }

  /// User-facing message for profile save/load failures (toast / inline error).
  static String userFacingMessage(Object error, {String fallback = 'Gagal menyimpan profil'}) {
    if (error is DioException) {
      final msg = error.message?.trim();
      if (msg != null &&
          msg.isNotEmpty &&
          !msg.toLowerCase().contains('dioexception')) {
        return msg;
      }
      final data = error.response?.data;
      if (data is Map) {
        final raw = Map<String, dynamic>.from(data);
        final specific = _firstValidationMessage(raw['errors']);
        if (specific != null && specific.isNotEmpty) return specific;
        final detail = raw['detail'] as String?;
        if (detail != null &&
            detail.isNotEmpty &&
            detail.toLowerCase() != 'validation error') {
          return detail;
        }
      }
      final code = error.response?.statusCode;
      if (code != null && code >= 500) {
        return 'Gagal menyimpan profil. Periksa kembali data paspor dan field wajib lainnya.';
      }
    }
    final raw = error.toString();
    if (raw.contains('passport_expiry_after_issue') ||
        raw.contains('passport_expiry_date')) {
      return 'Tanggal berakhir paspor harus setelah tanggal terbit paspor.';
    }
    return fallback;
  }

  DioException _handleError(DioException error) {
    final message = userFacingMessage(error, fallback: error.message ?? 'Terjadi kesalahan');
    if (message != error.message) {
      return DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        message: message,
      );
    }
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map) {
        final raw = Map<String, dynamic>.from(data);
        final specific = _firstValidationMessage(raw['errors']);
        if (specific != null && specific.isNotEmpty) {
          return DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            message: specific,
          );
        }
        final detail = raw['detail'] as String?;
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
