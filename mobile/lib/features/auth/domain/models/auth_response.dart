import 'user.dart';

class AuthResponse {
  final User user;
  final String accessToken;
  final String refreshToken;

  /// True when the backend says this Google account needs profile completion.
  /// Always false for email/password registration responses.
  final bool isNewGoogleUser;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.isNewGoogleUser = false,
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
      isNewGoogleUser: json['needs_registration'] == true,
    );
  }
}
