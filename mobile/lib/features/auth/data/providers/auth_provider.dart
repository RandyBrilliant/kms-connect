import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/api/interceptors.dart';
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
      state = state.copyWith(user: user.copyWith(emailVerified: true));
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
