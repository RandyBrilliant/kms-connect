import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/api/interceptors.dart';
import '../../../../core/services/google_sign_in_service.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../notifications/data/services/notification_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.read(authRepositoryProvider));
  // Wire force-logout so the interceptor can redirect to login when tokens expire.
  AuthInterceptor.onForceLogout = () {
    CustomToast.showGlobal(
      message: 'Sesi telah berakhir. Silakan masuk kembali.',
      type: ToastType.error,
    );
    notifier.forceSignOut();
  };
  ref.onDispose(() => AuthInterceptor.onForceLogout = null);
  return notifier;
});

class AuthState {
  final User? user;
  final bool isLoading;
  final bool initialized;
  final String? error;
  final String? errorCode;

  /// True after Google Sign-In for a brand-new account that still needs
  /// KTP upload, NIK, referral code, and phone to complete registration.
  final bool needsGoogleCompletion;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.initialized = false,
    this.error,
    this.errorCode,
    this.needsGoogleCompletion = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? initialized,
    String? error,
    String? errorCode,
    bool? needsGoogleCompletion,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
      error: error,
      errorCode: errorCode,
      needsGoogleCompletion: needsGoogleCompletion ?? this.needsGoogleCompletion,
    );
  }

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final isAuth = await _repository.isAuthenticated();
      if (isAuth) {
        final user = await _repository.getCurrentUser();
        state = state.copyWith(user: user, initialized: true);
        // Re-register FCM token now that we have a valid auth session.
        NotificationService().registerToken();
      } else {
        state = state.copyWith(initialized: true);
      }
    } catch (e) {
      // Not authenticated or error
      state = state.copyWith(user: null, initialized: true);
    }
  }

  /// Extracts a human-readable message from any exception.
  /// Prefers [DioException.message] (set by the repository's _handleError)
  /// over the raw toString() which includes noise like "DioException [bad_response]: ".
  String _extractErrorMessage(Object e, String fallback) {
    if (e is DioException) {
      final msg = e.message;
      if (msg != null && msg.isNotEmpty) return msg;
      // Fallback: read detail directly from response body
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return (data['detail'] as String?) ?? fallback;
      }
    }
    return fallback;
  }

  /// Extracts the backend `code` field from a DioException response body.
  String? _extractErrorCode(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['code'] as String?;
      }
    }
    return null;
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, errorCode: null);
    try {
      final authResponse = await _repository.login(email, password);
      state = state.copyWith(
        user: authResponse.user,
        isLoading: false,
      );
      NotificationService().registerToken();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Email atau password salah'),
        errorCode: _extractErrorCode(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String ktpFilePath,
    required String referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authResponse = await _repository.register(
        email: email,
        password: password,
        ktpFile: File(ktpFilePath),
        referralCode: referralCode,
      );
      state = state.copyWith(
        user: authResponse.user,
        isLoading: false,
      );
      NotificationService().registerToken();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Registrasi gagal'),
      );
      return false;
    }
  }

  Future<bool> googleAuth(String idToken) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authResponse = await _repository.googleAuth(idToken);
      state = state.copyWith(
        user: authResponse.user,
        isLoading: false,
      );
      NotificationService().registerToken();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Autentikasi gagal'),
      );
      return false;
    }
  }

  /// Full Google Sign-In flow: triggers the native Google account picker,
  /// then sends the ID token to the backend.
  ///
  /// Returns a [GoogleSignInResult]:
  /// - [GoogleSignInSuccess] — existing user authenticated, go to /home.
  /// - [GoogleSignInNeedsCompletion] — new account created, must visit /google-complete.
  /// - [GoogleSignInCancelled] — user dismissed the picker, no state changed.
  /// - [GoogleSignInError] — error message from SDK or backend.
  Future<GoogleAuthOutcome> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    // 1. Get ID token from the native Google Sign-In SDK.
    final tokenResult = await GoogleSignInService.getIdToken();
    if (tokenResult is GoogleSignInCancelled) {
      state = state.copyWith(isLoading: false);
      return const GoogleAuthOutcomeCancelled();
    }
    if (tokenResult is GoogleSignInError) {
      final errorResult = tokenResult;
      state = state.copyWith(
        isLoading: false,
        error: errorResult.message,
      );
      return GoogleAuthOutcomeError(errorResult.message);
    }

    // 2. Verify token with backend.
    try {
      final idToken = (tokenResult as GoogleSignInTokenObtained).idToken;
      final authResponse = await _repository.googleAuth(idToken);

      final needsCompletion = authResponse.isNewGoogleUser;
      state = state.copyWith(
        user: authResponse.user,
        isLoading: false,
        needsGoogleCompletion: needsCompletion,
      );

      if (!needsCompletion) {
        NotificationService().registerToken();
        return GoogleAuthOutcomeSuccess(authResponse.user);
      }
      return GoogleAuthOutcomeNeedsCompletion(authResponse.user);
    } catch (e) {
      final msg = _extractErrorMessage(e, 'Google Sign-In gagal');
      state = state.copyWith(isLoading: false, error: msg);
      return GoogleAuthOutcomeError(msg);
    }
  }

  /// Called after [GoogleCompleteRegistrationPage] successfully submits.
  /// Clears the completion flag and registers the FCM token.
  void markGoogleCompletionDone(User updatedUser) {
    state = state.copyWith(
      user: updatedUser,
      needsGoogleCompletion: false,
      isLoading: false,
    );
    NotificationService().registerToken();
  }

  /// Called after successful registration to set the authenticated user
  /// directly from the registration response (avoids a redundant network call).
  void setAuthenticatedUser(User user) {
    state = state.copyWith(user: user, isLoading: false, error: null);
  }

  Future<void> logout() async {
    // Unregister FCM token before clearing auth tokens
    try {
      await NotificationService().unregisterToken();
    } catch (_) {}
    await _repository.logout();
    state = const AuthState(initialized: true);
  }

  /// Called by [AuthInterceptor] when tokens are invalidated server-side
  /// (expired refresh token, revoked, etc.). Tokens are already cleared in
  /// storage by the interceptor — this just resets the Riverpod state so
  /// GoRouter redirects immediately to the login screen.
  void forceSignOut() {
    state = const AuthState(initialized: true);
  }

  Future<void> refreshUser() async {
    try {
      final user = await _repository.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(user: null);
    }
  }

  /// Resend verification email. Returns true on success.
  Future<bool> resendVerificationEmail(String email) async {
    try {
      await _repository.resendVerificationEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Outcome types for signInWithGoogle()
// ---------------------------------------------------------------------------

sealed class GoogleAuthOutcome {
  const GoogleAuthOutcome();
}

/// Google Sign-In succeeded and the user already has a complete profile.
final class GoogleAuthOutcomeSuccess extends GoogleAuthOutcome {
  final User? user;
  const GoogleAuthOutcomeSuccess(this.user);
}

/// Google Sign-In succeeded but the user needs to finish registration
/// (new account — must provide NIK, KTP, referral code, phone).
final class GoogleAuthOutcomeNeedsCompletion extends GoogleAuthOutcome {
  final User? user;
  const GoogleAuthOutcomeNeedsCompletion(this.user);
}

/// The user cancelled the Google account picker — no state was changed.
final class GoogleAuthOutcomeCancelled extends GoogleAuthOutcome {
  const GoogleAuthOutcomeCancelled();
}

/// An error occurred (network, backend error, etc.).
final class GoogleAuthOutcomeError extends GoogleAuthOutcome {
  final String message;
  const GoogleAuthOutcomeError(this.message);
}
