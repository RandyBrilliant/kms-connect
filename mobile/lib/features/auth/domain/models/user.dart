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
    final idRaw = json['id'];
    final id = idRaw is int
        ? idRaw
        : idRaw is num
            ? idRaw.toInt()
            : (int.tryParse(idRaw?.toString() ?? '') ?? 0);
    final emailRaw = json['email'];
    final email = emailRaw is String ? emailRaw : (emailRaw?.toString() ?? '');
    return User(
      id: id,
      email: email,
      fullName: json['full_name'] as String?,
      role: json['role'] as String? ?? 'applicant',
      isActive: json['is_active'] as bool? ?? true,
      emailVerified: json['email_verified'] as bool? ?? false,
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

  User copyWith({
    int? id,
    String? email,
    String? fullName,
    String? role,
    bool? isActive,
    bool? emailVerified,
    String? googleId,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      emailVerified: emailVerified ?? this.emailVerified,
      googleId: googleId ?? this.googleId,
    );
  }
}
