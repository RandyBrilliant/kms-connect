import 'package:dio/dio.dart';
import 'dart:io';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../domain/models/user.dart';
import '../../domain/models/auth_response.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  /// Login with email and password
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Login gagal',
        );
      }

      final authData = apiResponse.data!;
      final authResponse = AuthResponse.fromJson(authData);

      // Store tokens
      await _apiClient.setTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
      );

      // Debug: Verify tokens were stored
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        final storedAccess = await _apiClient.getAccessToken();
        print('TOKEN STORED (login): ${storedAccess != null && storedAccess.isNotEmpty}');
      }

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Register with email, password, and KTP file
  Future<AuthResponse> register({
    required String email,
    required String password,
    required File ktpFile,
    required String referralCode,
  }) async {
    try {
      final formData = FormData.fromMap({
        'email': email.trim().toLowerCase(),
        'password': password,
        'referral_code': referralCode.trim().toUpperCase(),
        'ktp': await MultipartFile.fromFile(
          ktpFile.path,
          filename: 'ktp.jpg',
        ),
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Registrasi gagal',
        );
      }

      final authData = apiResponse.data!;
      final authResponse = AuthResponse.fromJson(authData);

      // Store tokens
      await _apiClient.setTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
      );

      // Debug: Verify tokens were stored
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        final storedAccess = await _apiClient.getAccessToken();
        print('TOKEN STORED (register): ${storedAccess != null && storedAccess.isNotEmpty}');
      }

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Register/Login with Google Sign-In
  Future<AuthResponse> googleAuth(String idToken) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.googleAuth,
        data: {
          'id_token': idToken,
        },
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: apiResponse.detail ?? 'Google Sign-In gagal',
        );
      }

      final authData = apiResponse.data!;
      final authResponse = AuthResponse.fromJson(authData);

      // Store tokens
      await _apiClient.setTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
      );

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Logout - clear tokens
  Future<void> logout() async {
    await _apiClient.clearTokens();
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _apiClient.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current user info
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.me);
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess || apiResponse.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Gagal mengambil data pengguna',
        );
      }

      return User.fromJson(apiResponse.data!);
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
