import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../config/env.dart';

class GoogleSignInResult {
  final String idToken;
  final String? displayName;
  final String? email;

  GoogleSignInResult({required this.idToken, this.displayName, this.email});
}

class AppleSignInResult {
  final String identityToken;
  final String? fullName;
  final String? email;

  AppleSignInResult({required this.identityToken, this.fullName, this.email});
}

class SocialAuthService {
  static GoogleSignIn? _googleSignIn;

  static GoogleSignIn _ensureGoogleSignIn() {
    if (_googleSignIn != null) return _googleSignIn!;
    final webClientId = Env.googleWebClientId;
    if (kDebugMode) {
      debugPrint('GoogleSignIn serverClientId: '
          '${webClientId == null ? "(auto from google-services.json)" : webClientId}');
    }
    _googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: webClientId,
    );
    return _googleSignIn!;
  }

  /// Trigger Google Sign-In native flow and return the ID token.
  /// Throws on unrecoverable errors; returns null only if user cancelled.
  static Future<GoogleSignInResult?> signInWithGoogle() async {
    final client = _ensureGoogleSignIn();
    await client.signOut();
    final account = await client.signIn();
    if (account == null) return null; // user cancelled

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception('Google Sign-In berhasil tetapi tidak menerima ID token. '
          'Pastikan konfigurasi OAuth sudah benar.');
    }

    return GoogleSignInResult(
      idToken: idToken,
      displayName: account.displayName,
      email: account.email,
    );
  }

  /// Trigger Apple Sign-In native flow and return the identity token.
  /// Returns null only if the user cancelled; throws otherwise.
  static Future<AppleSignInResult?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        throw Exception('Apple Sign-In berhasil tetapi tidak menerima identity token.');
      }

      String? fullName;
      if (credential.givenName != null || credential.familyName != null) {
        fullName = [credential.givenName, credential.familyName]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
      }

      return AppleSignInResult(
        identityToken: identityToken,
        fullName: fullName,
        email: credential.email,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  /// Whether Apple Sign-In is available on this device.
  static bool get isAppleSignInAvailable => Platform.isIOS;
}
