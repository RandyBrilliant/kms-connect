import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/api/interceptors.dart';
import '../../../../core/widgets/custom_toast.dart';

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
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
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
        state = state.copyWith(user: user);
      }
    } catch (e) {
      // Not authenticated or error
      state = state.copyWith(user: null);
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

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authResponse = await _repository.login(email, password);
      state = state.copyWith(
        user: authResponse.user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Email atau password salah'),
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
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, 'Autentikasi gagal'),
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
    await _repository.logout();
    state = AuthState();
  }

  /// Called by [AuthInterceptor] when tokens are invalidated server-side
  /// (expired refresh token, revoked, etc.). Tokens are already cleared in
  /// storage by the interceptor — this just resets the Riverpod state so
  /// GoRouter redirects immediately to the login screen.
  void forceSignOut() {
    state = AuthState();
  }

  Future<void> refreshUser() async {
    try {
      final user = await _repository.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(user: null);
    }
  }
}
