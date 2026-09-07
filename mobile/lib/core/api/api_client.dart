import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/env.dart';
import 'certificate_pinning.dart';
import 'interceptors.dart';
import 'token_storage_policy.dart';

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

  /// Debug-only: iOS Simulator Keychain is often missing without code signing.
  bool _useSharedPrefsFallback = false;

  /// Profile/release: Keychain probe failed — never store tokens in plaintext.
  bool _secureStorageUnavailable = false;

  Dio get dio => _dio;

  /// Binary downloads (PDFs) must never be served from the HTTP cache.
  static Options uncachedBytes({Duration? receiveTimeout}) {
    return Options(
      responseType: ResponseType.bytes,
      receiveTimeout: receiveTimeout,
      headers: const {'Accept': 'application/pdf'},
      extra: CacheOptions(
        store: null,
        policy: CachePolicy.noCache,
      ).toExtra(),
    );
  }

  /// JSON requests that must always hit the network (profile read/write).
  static Options noCache() {
    return Options(
      extra: CacheOptions(
        store: null,
        policy: CachePolicy.noCache,
      ).toExtra(),
    );
  }

  Future<void> initialize() async {
    // Probe Keychain availability — write+read a test value.
    try {
      await _secureStorage.write(key: '__probe__', value: 'ok');
      final v = await _secureStorage.read(key: '__probe__');
      if (v != 'ok') throw Exception('read-back mismatch');
      await _secureStorage.delete(key: '__probe__');
      // Drop leftover plaintext tokens from older builds that used the fallback.
      await _clearPrefsTokens();
    } catch (e) {
      if (allowInsecureTokenFallback(debugMode: kDebugMode)) {
        _useSharedPrefsFallback = true;
        debugPrint(
          'Keychain unavailable, using SharedPreferences fallback (debug only): $e',
        );
      } else {
        _secureStorageUnavailable = true;
        await _clearPrefsTokens();
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

    _dio.httpClientAdapter = IOHttpClientAdapter(
      validateCertificate: createCertificateValidator(
        apiBaseUrl: Env.apiBaseUrl,
        debugMode: kDebugMode,
      ),
    );

    await _setupCache();

    _dio.interceptors.addAll([
      AuthInterceptor(this, _dio),
      if (kDebugMode) LoggingInterceptor(),
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
  // Token storage — Keychain; SharedPreferences only in debug
  // ---------------------------------------------------------------------------

  void _ensureSecureStorageAvailable() {
    if (_secureStorageUnavailable) {
      throw const SecureStorageUnavailableException();
    }
  }

  Future<void> _clearPrefsTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
    } catch (_) {}
  }

  Future<void> setTokens(String accessToken, String refreshToken) async {
    _ensureSecureStorageAvailable();
    if (_useSharedPrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
      return;
    }
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    if (_useSharedPrefsFallback) {
      await _clearPrefsTokens();
      return;
    }
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (_) {}
    await _clearPrefsTokens();
  }

  Future<String?> getAccessToken() async {
    if (_secureStorageUnavailable) return null;
    if (_useSharedPrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    }
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    if (_secureStorageUnavailable) return null;
    if (_useSharedPrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    }
    return await _secureStorage.read(key: _refreshTokenKey);
  }
}
