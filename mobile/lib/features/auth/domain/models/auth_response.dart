import 'user.dart';

class AuthResponse {
  final User user;
  final String accessToken;
  final String refreshToken;

  /// True when the backend says this social account needs profile completion
  /// (KTP upload, NIK, etc.). Set for both Google and Apple flows.
  final bool needsRegistration;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.needsRegistration = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userData = json['user'];
    if (userData == null || userData is! Map<String, dynamic>) {
      throw FormatException(
        'Invalid auth response: missing or invalid user data. '
        'Your account may have been created; please try logging in.',
      );
    }
    return AuthResponse(
      user: User.fromJson(userData),
      accessToken: json['access'] as String? ?? '',
      refreshToken: json['refresh'] as String? ?? '',
      needsRegistration: json['needs_registration'] == true,
    );
  }
}
