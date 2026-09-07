import '../domain/models/user.dart';

/// Fields stored for offline session restore. Social IDs stay out of the blob.
Map<String, dynamic> sessionCachePayload(User user) {
  return {
    'id': user.id,
    'email': user.email,
    'full_name': user.fullName,
    'role': user.role,
    'is_active': user.isActive,
    'email_verified': user.emailVerified,
  };
}

User userFromSessionCache(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('cached user is not a map');
  }
  return User.fromJson(Map<String, dynamic>.from(raw));
}
