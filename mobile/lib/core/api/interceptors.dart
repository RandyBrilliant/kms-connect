import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'endpoints.dart';

/// Authentication interceptor - adds JWT token to requests and handles refresh
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _secureStorage;
  final Dio _dio;
  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})> _pendingRequests = [];

  AuthInterceptor(this._secureStorage, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip auth for public endpoints
    if (_isPublicEndpoint(options.path)) {
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        print('PUBLIC ENDPOINT: ${options.path} - skipping auth header');
      }
      handler.next(options);
      return;
    }

    final token = await _secureStorage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        print('AUTH HEADER ADDED for: ${options.path}');
      }
    } else {
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        print('NO TOKEN FOUND for: ${options.path}');
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Skip token refresh for public endpoints - they shouldn't require auth
    if (_isPublicEndpoint(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    // Handle 401 Unauthorized - try to refresh token
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;

      try {
        final refreshToken = await _secureStorage.read(key: 'refresh_token');
        if (refreshToken == null) {
          _isRefreshing = false;
          _rejectPendingRequests(err);
          handler.reject(err);
          return;
        }

        // Try to refresh token
        final response = await _dio.post(
          ApiEndpoints.refreshToken,
          data: {'refresh': refreshToken},
        );

        if (response.statusCode == 200) {
          final newAccessToken = response.data['access'] as String?;
          if (newAccessToken != null) {
            await _secureStorage.write(key: 'access_token', value: newAccessToken);

            // Retry original request
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccessToken';
            final retryResponse = await _dio.fetch(opts);
            _isRefreshing = false;
            _resolvePendingRequests(retryResponse);
            handler.resolve(retryResponse);
            return;
          }
        }
      } catch (e) {
        // Refresh failed - clear tokens and reject
        await _secureStorage.deleteAll();
        _isRefreshing = false;
        _rejectPendingRequests(err);
      }
    }

    _isRefreshing = false;
    handler.next(err);
  }

  bool _isPublicEndpoint(String path) {
    return path.contains('/auth/') ||
        path.contains('/public/') ||
        path.contains('/document-types/public/');
  }

  void _resolvePendingRequests(Response response) {
    for (final pending in _pendingRequests) {
      pending.handler.resolve(response);
    }
    _pendingRequests.clear();
  }

  void _rejectPendingRequests(DioException error) {
    for (final pending in _pendingRequests) {
      pending.handler.reject(error);
    }
    _pendingRequests.clear();
  }
}

/// Logging interceptor - logs requests and responses in debug mode
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      print('REQUEST[${options.method}] => PATH: ${options.path}');
      if (options.data != null) {
        print('DATA: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      print('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      print('ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}');
      print('MESSAGE: ${err.message}');
      // Try to extract backend error detail
      if (err.response?.data != null) {
        try {
          final data = err.response!.data;
          print('RESPONSE DATA TYPE: ${data.runtimeType}');
          print('RESPONSE DATA: $data');
          if (data is Map<String, dynamic>) {
            final detail = data['detail'] as String?;
            if (detail != null) {
              print('BACKEND ERROR: $detail');
            }
            final errors = data['errors'] as Map<String, dynamic>?;
            if (errors != null && errors.isNotEmpty) {
              print('VALIDATION ERRORS: $errors');
            }
          } else if (data is String) {
            print('BACKEND ERROR (string): $data');
          }
        } catch (e) {
          print('Error parsing response: $e');
        }
      } else {
        print('No response data available');
      }
    }
    handler.next(err);
  }
}

/// Error interceptor - formats errors consistently
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Error formatting is handled in repositories/services
    handler.next(err);
  }
}
