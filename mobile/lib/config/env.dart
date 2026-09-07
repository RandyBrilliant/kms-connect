import 'package:flutter/foundation.dart';

/// Production API used when `--dart-define=API_BASE_URL=...` is omitted.
const kProductionApiBaseUrl = 'https://data.kms-connect.com';

/// Compile-time app config. Values come from `--dart-define`, not from a
/// bundled `.env` file (which would ship inside the APK/IPA).
///
/// Local backend examples:
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///   flutter run --dart-define=API_BASE_URL=http://192.168.0.244:8000
class Env {
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    return resolveApiBaseUrl(fromDefine: fromDefine);
  }

  /// Web OAuth client ID (`*.apps.googleusercontent.com`). Same value as backend
  /// `GOOGLE_CLIENT_ID`. Optional if `google-services.json` already lists `oauth_client`.
  static String? get googleWebClientId {
    const v = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    final trimmed = v.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}

@visibleForTesting
String resolveApiBaseUrl({required String fromDefine}) {
  final trimmed = fromDefine.trim();
  if (trimmed.isNotEmpty) return trimmed;
  return kProductionApiBaseUrl;
}
