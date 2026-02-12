class User {
  final int id;
  final String email;
  final String? fullName;
  final String role;
  final bool isActive;
  final bool emailVerified;
  final String? googleId;

  User({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    required this.isActive,
    required this.emailVerified,
    this.googleId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      emailVerified: json['email_verified'] as bool,
      googleId: json['google_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
      'email_verified': emailVerified,
      'google_id': googleId,
    };
  }
}
