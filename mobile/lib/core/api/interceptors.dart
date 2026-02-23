import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'endpoints.dart';

/// Authentication interceptor - adds JWT token to requests and handles refresh
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _secureStorage;
  final Dio _dio;
  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})> _pendingRequests = [];

  /// Set this from outside (e.g. authStateProvider) so that when the
  /// interceptor invalidates tokens it can force GoRouter to redirect to login.
  static void Function()? onForceLogout;

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
      handler.next(options);
    } else {
      // No token for a protected endpoint — reject immediately and force the
      // user back to the login screen rather than sending an unauthenticated
      // request that will just bounce back as a 401 we cannot recover from.
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        print('NO TOKEN — forcing logout for: ${options.path}');
      }
      _dispatchForceLogout();
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: 'Sesi telah berakhir. Silakan masuk kembali.',
        ),
      );
    }
  }

  /// Clears tokens from storage and notifies the app to redirect to login.
  Future<void> _dispatchForceLogout() async {
    await _secureStorage.deleteAll();
    onForceLogout?.call();
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Skip token refresh for public endpoints - they shouldn't require auth
    if (_isPublicEndpoint(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    // If this was already a retry after refresh, reject cleanly without clearing tokens
    // (avoids infinite loop and incorrectly wiping credentials on transient failures)
    if (err.requestOptions.extra['auth_retry'] == true) {
      handler.next(err);
      return;
    }

    // Handle 401 Unauthorized - try to refresh token
    if (err.response?.statusCode == 401) {
      if (_isRefreshing) {
        // Refresh already in-flight — queue this request to retry once it completes
        _pendingRequests.add((options: err.requestOptions, handler: handler));
        return;
      }

      _isRefreshing = true;

      try {
        final refreshToken = await _secureStorage.read(key: 'refresh_token');
        if (refreshToken == null) {
          _isRefreshing = false;
          await _dispatchForceLogout();
          _rejectPendingRequests(err);
          handler.reject(err);
          return;
        }

        // Try to refresh token (public endpoint — won't re-enter this interceptor)
        final response = await _dio.post(
          ApiEndpoints.refreshToken,
          data: {'refresh': refreshToken},
        );

        if (response.statusCode == 200) {
          final newAccessToken = response.data['access'] as String?;
          if (newAccessToken != null) {
            await _secureStorage.write(key: 'access_token', value: newAccessToken);

            // Mark as retry so a second 401 on the retry doesn't wipe tokens
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccessToken';
            opts.extra['auth_retry'] = true;

            try {
              final retryResponse = await _dio.fetch(opts);
              _isRefreshing = false;
              _resolvePendingRequests(retryResponse);
              handler.resolve(retryResponse);
            } catch (retryErr) {
              // Retry itself failed — reject but do NOT clear tokens
              _isRefreshing = false;
              _rejectPendingRequests(err);
              handler.next(err);
            }
            return;
          }
        }

        // Refresh response was not 200 or contained no access token — credentials invalid
        _isRefreshing = false;
        await _dispatchForceLogout();
        _rejectPendingRequests(err);
        handler.next(err);
      } catch (e) {
        // Refresh request itself threw (network error, server down) — clear tokens
        _isRefreshing = false;
        await _dispatchForceLogout();
        _rejectPendingRequests(err);
        handler.next(err);
      }
      return;
    }

    handler.next(err);
  }

  bool _isPublicEndpoint(String path) {
    return path.contains('/auth/') ||
        path.contains('/document-types/public/') ||
        path.contains('/provinces/') ||
        path.contains('/regencies/') ||
        path.contains('/districts/') ||
        path.contains('/villages/');
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
