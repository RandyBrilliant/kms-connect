import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../config/env.dart';
import 'interceptors.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  Dio get dio => _dio;

  Future<void> initialize() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Setup cache interceptor
    await _setupCache();

    // Add interceptors
    _dio.interceptors.addAll([
      AuthInterceptor(_secureStorage, _dio),
      LoggingInterceptor(),
      ErrorInterceptor(),
    ]);
  }

  Future<void> _setupCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cachePath = path.join(cacheDir.path, 'api_cache');
      final cacheStore = HiveCacheStore(cachePath);

      final cacheOptions = CacheOptions(
        store: cacheStore,
        // Always fetch from network; only serve cached data on network errors
        // (offline fallback). CachePolicy.request would serve a stale empty
        // response from a previous run, making endpoints appear "not hit".
        policy: CachePolicy.refresh,
        hitCacheOnErrorExcept: [401, 403],
        maxStale: const Duration(hours: 1),
        priority: CachePriority.normal,
        cipher: null,
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        allowPostMethod: false,
      );

      _dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
    } catch (e) {
      // Cache setup failed, continue without cache
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        // ignore: avoid_print
        print('Cache setup failed: $e');
      }
    }
  }

  Future<void> setTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }
}
