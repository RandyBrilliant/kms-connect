import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Falls back to SharedPreferences when iOS Keychain is unavailable
  /// (e.g. simulator with CODE_SIGNING_ALLOWED=NO strips entitlements).
  bool _useSharedPrefsFallback = false;

  Dio get dio => _dio;

  Future<void> initialize() async {
    // Probe Keychain availability — write+read a test value.
    try {
      await _secureStorage.write(key: '__probe__', value: 'ok');
      final v = await _secureStorage.read(key: '__probe__');
      if (v != 'ok') throw Exception('read-back mismatch');
      await _secureStorage.delete(key: '__probe__');
    } catch (e) {
      _useSharedPrefsFallback = true;
      if (kDebugMode) {
        debugPrint('Keychain unavailable, using SharedPreferences fallback: $e');
      }
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Type': 'mobile',
        },
      ),
    );

    await _setupCache();

    _dio.interceptors.addAll([
      AuthInterceptor(this, _dio),
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
      if (kDebugMode) debugPrint('Cache setup failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Token storage — Keychain with SharedPreferences fallback
  // ---------------------------------------------------------------------------

  Future<void> setTokens(String accessToken, String refreshToken) async {
    if (_useSharedPrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
    } else {
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> clearTokens() async {
    if (_useSharedPrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
    } else {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    }
  }

  Future<String?> getAccessToken() async {
    if (_useSharedPrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    }
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    if (_useSharedPrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    }
    return await _secureStorage.read(key: _refreshTokenKey);
  }
}
