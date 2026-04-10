import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
  static final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// Trigger Google Sign-In native flow and return the ID token.
  /// Returns null if the user cancelled.
  static Future<GoogleSignInResult?> signInWithGoogle() async {
    try {
      // Sign out first to always show the account picker
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return null;

      return GoogleSignInResult(
        idToken: idToken,
        displayName: account.displayName,
        email: account.email,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  /// Trigger Apple Sign-In native flow and return the identity token.
  /// Returns null if the user cancelled.
  static Future<AppleSignInResult?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) return null;

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
      if (kDebugMode) debugPrint('Apple Sign-In error: $e');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Apple Sign-In error: $e');
      return null;
    }
  }

  /// Whether Apple Sign-In is available on this device.
  static bool get isAppleSignInAvailable => Platform.isIOS;
}
