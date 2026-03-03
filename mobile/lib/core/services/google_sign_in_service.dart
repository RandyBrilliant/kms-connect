import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Result of a Google Sign-In attempt.
sealed class GoogleSignInResult {
  const GoogleSignInResult();
}

/// User confirmed & ID token obtained. Backend call can now be made.
final class GoogleSignInTokenObtained extends GoogleSignInResult {
  final String idToken;
  const GoogleSignInTokenObtained(this.idToken);
}

/// User dismissed the account picker or denied permission.
final class GoogleSignInCancelled extends GoogleSignInResult {
  const GoogleSignInCancelled();
}

/// An unexpected error occurred (platform exception, etc.)
final class GoogleSignInError extends GoogleSignInResult {
  final String message;
  const GoogleSignInError(this.message);
}

/// Thin wrapper around the `google_sign_in` package.
///
/// Responsibilities:
/// - Request the minimum required scopes (email + profile).
/// - Obtain and return the Google ID token for backend verification.
/// - Expose [signOut] so other services can clean up the Google session.
///
/// **Setup required (see README / ANDROID_SETUP.md):**
/// - Android: SHA-1 fingerprint registered in Firebase Console.
///   The `GOOGLE_WEB_CLIENT_ID` must be provided in `clientId` if your
///   `google-services.json` uses a web OAuth client (recommended for backend).
/// - iOS: `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` added to
///   `CFBundleURLSchemes` in `ios/Runner/Info.plist`.
class GoogleSignInService {
  GoogleSignInService._();

  /// Web client ID from Google Cloud Console → OAuth 2.0 Credentials.
  /// Required so the backend can verify the ID token with the same audience.
  /// Set via dart-define: `--dart-define=GOOGLE_WEB_CLIENT_ID=...`
  static const _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Providing the web client ID makes Google issue an ID token that the
    // backend can verify using `google-auth-library` (same audience).
    clientId: _webClientId.isNotEmpty ? _webClientId : null,
    scopes: ['email', 'profile'],
  );

  /// Initiates the Google account-picker flow and returns the ID token.
  ///
  /// Returns [GoogleSignInTokenObtained] on success,
  /// [GoogleSignInCancelled] if the user dismissed the picker, or
  /// [GoogleSignInError] on unexpected errors.
  static Future<GoogleSignInResult> getIdToken() async {
    try {
      // Sign out first to always show the account picker (better UX).
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleSignInCancelled();
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        if (kDebugMode) debugPrint('[GoogleSignIn] ID token is null');
        return const GoogleSignInError(
          'Gagal mendapatkan token dari Google. Pastikan Web Client ID dikonfigurasi.',
        );
      }

      return GoogleSignInTokenObtained(idToken);
    } catch (e) {
      if (kDebugMode) debugPrint('[GoogleSignIn] Error: $e');
      return GoogleSignInError(_friendlyError(e.toString()));
    }
  }

  /// Signs the user out of Google (clears cached account).
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  static String _friendlyError(String raw) {
    if (raw.contains('network_error')) return 'Tidak ada koneksi internet.';
    if (raw.contains('sign_in_cancelled')) return 'Login Google dibatalkan.';
    if (raw.contains('sign_in_failed')) return 'Login Google gagal.';
    return 'Login Google gagal. Silakan coba lagi.';
  }
}
