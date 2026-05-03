import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../core/widgets/professional_phone_field.dart';
import '../../domain/models/user.dart';
import '../../domain/models/auth_response.dart';
import '../../domain/models/ktp_data.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  static const String _cachedUserKey = 'auth_cached_user_json';

  /// Last known user from a successful `/me` (or login) — used to restore the
  /// session UI when the network is unavailable on cold start.
  Future<void> persistCachedUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));
  }

  Future<User?> loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
  }

  /// Login with email and password
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {'email': email.trim().toLowerCase(), 'password': password},
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
      AuthResponse authResponse;
      try {
        authResponse = AuthResponse.fromJson(authData);
      } catch (e) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message:
              'Login berhasil di server, tetapi data respons tidak valid. Coba lagi.',
        );
      }

      // Store tokens — wrap in try/catch so Keychain/SecureStorage failures
      // don't mask as "wrong password".
      try {
        await _apiClient.setTokens(
          authResponse.accessToken,
          authResponse.refreshToken,
        );
      } catch (storageErr) {
        if (const bool.fromEnvironment('dart.vm.product') == false) {
          print('TOKEN STORAGE FAILED: $storageErr');
        }
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.unknown,
          message:
              'Login berhasil, tetapi gagal menyimpan sesi. '
              'Pastikan Keychain/storage tersedia dan coba lagi.',
        );
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
        'ktp': await MultipartFile.fromFile(ktpFile.path, filename: 'ktp.jpg'),
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
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
      AuthResponse authResponse;
      try {
        authResponse = AuthResponse.fromJson(authData);
      } catch (e) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: e is FormatException
              ? e.message
              : 'Registrasi berhasil, tetapi data respons tidak valid. Silakan coba masuk dengan email dan kata sandi Anda.',
        );
      }

      try {
        await _apiClient.setTokens(
          authResponse.accessToken,
          authResponse.refreshToken,
        );
      } catch (storageErr) {
        if (const bool.fromEnvironment('dart.vm.product') == false) {
          print('TOKEN STORAGE FAILED (register): $storageErr');
        }
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.unknown,
          message:
              'Registrasi berhasil, tetapi gagal menyimpan sesi. Coba login.',
        );
      }

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Preview OCR data from KTP image before registration
  Future<KtpData> ocrPreview(File ktpFile) async {
    try {
      // Compress KTP image before uploading for OCR.
      final compressed = await ImageCompressor.compressDocument(ktpFile);
      final formData = FormData.fromMap({
        'ktp': await MultipartFile.fromFile(
          compressed.path,
          filename: 'ktp.jpg',
        ),
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.ocrPreview,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
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
          message: apiResponse.detail ?? 'OCR gagal memproses KTP',
        );
      }

      return KtpData.fromJson(apiResponse.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Register with email, password, NIK, and KTP file
  Future<AuthResponse> registerComplete({
    required String email,
    required String password,
    required String nik,
    required File ktpFile,
    String? referralCode,
    String? fullName,
    String? phoneNumber,
    String? birthPlaceText,
    String? birthDateIso,
    bool? dataDeclarationConfirmed,
  }) async {
    try {
      // Compress KTP image before uploading to save bandwidth.
      final compressed = await ImageCompressor.compressDocument(ktpFile);
      final formData = FormData.fromMap({
        'email': email.trim().toLowerCase(),
        'password': password,
        'nik': nik.trim(),
        'ktp': await MultipartFile.fromFile(
          compressed.path,
          filename: 'ktp.jpg',
        ),
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode.trim().toUpperCase(),
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone_number': ProfessionalPhoneField.toIndonesiaE164(phoneNumber),
        if (birthPlaceText != null && birthPlaceText.trim().isNotEmpty)
          'birth_place_text': birthPlaceText.trim(),
        'birth_date': ?birthDateIso,
        'data_declaration_confirmed': ?dataDeclarationConfirmed,
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
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
      AuthResponse authResponse;
      try {
        authResponse = AuthResponse.fromJson(authData);
      } catch (e) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: e is FormatException
              ? e.message
              : 'Registrasi berhasil, tetapi data respons tidak valid. Silakan coba masuk dengan email dan kata sandi Anda.',
        );
      }

      try {
        await _apiClient.setTokens(
          authResponse.accessToken,
          authResponse.refreshToken,
        );
      } catch (storageErr) {
        if (const bool.fromEnvironment('dart.vm.product') == false) {
          print('TOKEN STORAGE FAILED (registerComplete): $storageErr');
        }
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.unknown,
          message:
              'Registrasi berhasil, tetapi gagal menyimpan sesi. Coba login.',
        );
      }

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Complete social auth profile (upload KTP + basic identity fields).
  /// Called after Google/Apple Sign-In when needs_registration is true.
  Future<User> socialComplete({
    required String nik,
    required File ktpFile,
    String? fullName,
    String? birthPlaceText,
    String? birthDateIso,
  }) async {
    try {
      final compressed = await ImageCompressor.compressDocument(ktpFile);
      final formData = FormData.fromMap({
        'nik': nik.trim(),
        'ktp': await MultipartFile.fromFile(
          compressed.path,
          filename: 'ktp.jpg',
        ),
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
        if (birthPlaceText != null && birthPlaceText.trim().isNotEmpty)
          'birth_place_text': birthPlaceText.trim(),
        'birth_date': ?birthDateIso,
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.socialComplete,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
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
          message: apiResponse.detail ?? 'Gagal melengkapi profil',
        );
      }

      final userData = apiResponse.data!['user'];
      if (userData == null || userData is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Profil berhasil disimpan tetapi data respons tidak valid.',
        );
      }

      return User.fromJson(userData);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Logout - invalidate refresh token on backend, unregister FCM, then clear local tokens
  Future<void> logout() async {
    try {
      final refreshToken = await _apiClient.getRefreshToken();
      if (refreshToken != null) {
        await _apiClient.dio.post(
          ApiEndpoints.logout,
          data: {'refresh': refreshToken},
        );
      }
    } catch (_) {
      // Server logout failed — still clear local tokens
    }
    await _apiClient.clearTokens();
    await clearCachedUser();
  }

  /// Sign in with Google (send ID token to backend)
  Future<AuthResponse> googleSignIn(String idToken) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.googleSignIn,
        data: {'id_token': idToken},
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
          message: apiResponse.detail ?? 'Google Sign-In gagal',
        );
      }

      final authResponse = AuthResponse.fromJson(apiResponse.data!);
      await _apiClient.setTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
      );
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Sign in with Apple (send identity token to backend)
  Future<AuthResponse> appleSignIn(
    String identityToken, {
    String? fullName,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.appleSignIn,
        data: {
          'identity_token': identityToken,
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        },
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
          message: apiResponse.detail ?? 'Apple Sign-In gagal',
        );
      }

      final authResponse = AuthResponse.fromJson(apiResponse.data!);
      await _apiClient.setTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
      );
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Link Google account to current user
  Future<void> linkGoogleAccount(String idToken) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.linkGoogle,
        data: {'id_token': idToken},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Link Apple account to current user
  Future<void> linkAppleAccount(String identityToken) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.linkApple,
        data: {'identity_token': identityToken},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Resend verification email for the given email address.
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.resendVerificationEmail,
        data: {'email': email.trim().toLowerCase()},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update email for an unverified account, then trigger a new verification email.
  Future<void> updateUnverifiedEmail({
    required String currentEmail,
    required String newEmail,
    required String password,
  }) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.updateUnverifiedEmail,
        data: {
          'current_email': currentEmail.trim().toLowerCase(),
          'new_email': newEmail.trim().toLowerCase(),
          'password': password,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
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
