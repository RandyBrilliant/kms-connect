import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/auth_response.dart';
import '../../domain/models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/social_auth_service.dart';
import '../../../../core/api/interceptors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../notifications/data/services/notification_service.dart';

bool _isTransientNetworkError(Object e) {
  if (e is! DioException) return false;
  return e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError ||
      (e.type == DioExceptionType.unknown && e.response == null);
}

bool _isServerError(Object e) {
  if (e is! DioException) return false;
  final code = e.response?.statusCode;
  return code != null && code >= 500 && code < 600;
}

/// Offline / flaky network or server errors: safe to show last known user.
bool _shouldRecoverSessionWithCache(Object e) {
  return _isTransientNetworkError(e) || _isServerError(e);
}

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

  const AuthState({
    this.user,
    this.isLoading = false,
    this.initialized = false,
    this.error,
    this.errorCode,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? initialized,
    String? error,
    String? errorCode,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
      error: error,
      errorCode: errorCode,
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
      if (!isAuth) {
        state = state.copyWith(initialized: true);
        return;
      }
      try {
        final user = await _repository.getCurrentUser();
        await _repository.persistCachedUser(user);
        state = state.copyWith(user: user, initialized: true);
        NotificationService().registerToken();
      } catch (e) {
        final stillAuth = await _repository.isAuthenticated();
        if (!stillAuth) {
          await _repository.clearCachedUser();
          state = state.copyWith(user: null, initialized: true);
          return;
        }
        final cached = await _repository.loadCachedUser();
        if (cached != null && _shouldRecoverSessionWithCache(e)) {
          state = state.copyWith(user: cached, initialized: true);
          NotificationService().registerToken();
          return;
        }
        if (_isTransientNetworkError(e)) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          try {
            final user = await _repository.getCurrentUser();
            await _repository.persistCachedUser(user);
            state = state.copyWith(user: user, initialized: true);
            NotificationService().registerToken();
          } catch (_) {
            state = state.copyWith(user: null, initialized: true);
          }
          return;
        }
        state = state.copyWith(user: null, initialized: true);
      }
    } catch (_) {
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
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return (data['detail'] as String?) ?? fallback;
      }
    }
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      print('NON-DIO EXCEPTION in auth: ${e.runtimeType}: $e');
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
      await _repository.persistCachedUser(authResponse.user);
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
      await _repository.persistCachedUser(authResponse.user);
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

  /// Google Sign-In: trigger native flow, send token to backend.
  /// Returns the AuthResponse on success (caller checks needsRegistration).
  Future<AuthResponse?> googleSignIn() async {
    state = state.copyWith(isLoading: true, error: null, errorCode: null);
    try {
      final result = await SocialAuthService.signInWithGoogle();
      if (result == null) {
        state = state.copyWith(isLoading: false);
        return null;
      }

      final authResponse = await _repository.googleSignIn(result.idToken);
      await _repository.persistCachedUser(authResponse.user);
      state = state.copyWith(user: authResponse.user, isLoading: false);
      NotificationService().registerToken();
      return authResponse;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Google Sign-In gagal'),
        errorCode: _extractErrorCode(e),
      );
      return null;
    }
  }

  /// Apple Sign-In: trigger native flow, send token to backend.
  /// Returns the AuthResponse on success (caller checks needsRegistration).
  Future<AuthResponse?> appleSignIn() async {
    state = state.copyWith(isLoading: true, error: null, errorCode: null);
    try {
      final result = await SocialAuthService.signInWithApple();
      if (result == null) {
        state = state.copyWith(isLoading: false);
        return null;
      }

      final authResponse = await _repository.appleSignIn(
        result.identityToken,
        fullName: result.fullName,
      );
      await _repository.persistCachedUser(authResponse.user);
      state = state.copyWith(user: authResponse.user, isLoading: false);
      NotificationService().registerToken();
      return authResponse;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Apple Sign-In gagal'),
        errorCode: _extractErrorCode(e),
      );
      return null;
    }
  }

  /// Link Google account to current user's profile.
  Future<bool> linkGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await SocialAuthService.signInWithGoogle();
      if (result == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      await _repository.linkGoogleAccount(result.idToken);
      await refreshUser();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Gagal menghubungkan akun Google'),
      );
      return false;
    }
  }

  /// Link Apple account to current user's profile.
  Future<bool> linkApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await SocialAuthService.signInWithApple();
      if (result == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      await _repository.linkAppleAccount(result.identityToken);
      await refreshUser();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Gagal menghubungkan akun Apple'),
      );
      return false;
    }
  }

  /// Called after successful registration to set the authenticated user
  /// directly from the registration response (avoids a redundant network call).
  void setAuthenticatedUser(User user) {
    state = state.copyWith(user: user, isLoading: false, error: null);
    unawaited(_repository.persistCachedUser(user));
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
    unawaited(_repository.clearCachedUser());
    state = const AuthState(initialized: true);
  }

  Future<void> refreshUser() async {
    try {
      final user = await _repository.getCurrentUser();
      await _repository.persistCachedUser(user);
      state = state.copyWith(user: user);
    } catch (_) {
      // Keep existing user state on failure — do not log out the user
      // just because a background refresh failed (e.g. momentary network issue).
    }
  }

  /// After successful OTP email verification, mark the current user's email
  /// as verified directly in state. This guarantees the router redirects to
  /// /home even if a subsequent refreshUser() returns stale data.
  void markEmailVerified() {
    final user = state.user;
    if (user != null) {
      final updated = user.copyWith(emailVerified: true);
      state = state.copyWith(user: updated);
      unawaited(_repository.persistCachedUser(updated));
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

  Future<bool> updateUnverifiedEmail({
    required String currentEmail,
    required String newEmail,
    required String password,
  }) async {
    try {
      await _repository.updateUnverifiedEmail(
        currentEmail: currentEmail,
        newEmail: newEmail,
        password: password,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
