import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  /// Web OAuth client ID (`*.apps.googleusercontent.com`). Same value as backend
  /// `GOOGLE_CLIENT_ID`. Optional if `google-services.json` already lists `oauth_client`,
  /// but required for a reliable ID token when Firebase config has empty `oauth_client`.
  static String? get googleWebClientId {
    final v = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }
}
